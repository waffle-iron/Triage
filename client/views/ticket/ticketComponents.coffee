Template.ticketChangelogItem.helpers
  changeIsType: (type) ->
    @type is type
  note: ->
    if this.type is "note" then return true else return false
  file: ->
    FileRegistry.findOne {_id: this.valueOf()}

Template.ticketInfoTable.onRendered ->
  doc = @find 'tr:last td:last'
  doc.ondragover = (e) ->
    @className = 'hover'
    e.preventDefault()
    false


  doc.ondragend = (e) ->
    @className = ''
    e.preventDefault()
    false

  data = @data

  doc.ondrop = (e) ->
    e.preventDefault()
    files = e.dataTransfer.files[0]
    console.log files

    for item in e.dataTransfer.items
      entry = item.webkitGetAsEntry()
      if entry.isFile
        files = e.dataTransfer.files
        for file in files
          FileRegistry.upload file, (fileId) ->
            file = FileRegistry.findOne(fileId)
            console.log 'callback FileRegistry.upload(file,cb)'
            #console.log 'uploaded file', file, ' to ', data
            Tickets.update data._id, {$addToSet: {attachmentIds: fileId}}
            Meteor.call 'setFlag', Meteor.userId(), data._id, 'attachment', true
      else if entry.isDirectory
        traverse = (item, path) ->
          path = path || ''
          if item.isFile
            item.file (file) ->
              FileRegistry.upload file, ->
                console.log 'callback FileRegistry.upload(file,cb)'
          else if item.isDirectory
            item.createReader().readEntries (entries) ->
              traverse entry, path + item.name + '/' for entry in entries
        traverse entry, ''
    false

Template.ticketInfoTable.helpers
  admin: ->
    _.contains Queues.findOne({name: @queueName})?.memberIds, Meteor.userId()
  file: ->
    FileRegistry.findOne {_id: this.valueOf()}
  userSettings: ->
    {
      position: "top"
      limit: 5
      rules: [
        collection: Meteor.users
        field: 'username'
        template: Template.userPill
        noMatchTemplate: Template.noMatchUserPill
      ]
    }
  tagSettings: ->
    {
      position: "top"
      limit: 5
      rules: [
        collection: Tags
        field: 'name'
        template: Template.tagPill
        noMatchTemplate: Template.noMatchTagPill
      ]
    }

Template.removeAttachmentModal.helpers
  attachment: -> FileRegistry.findOne(@attachmentId)
  ticket: -> Tickets.findOne(@ticketId)

Template.removeAttachmentModal.events
  'click button[data-action=removeAttachment]': (e, tpl) ->
    Tickets.update @ticketId, {$pull: {attachmentIds: @attachmentId}}
    $('#removeAttachmentModal').modal('hide')
  'hidden.bs.modal': (e, tpl) ->
    Blaze.remove tpl.view

Template.ticketInfoTable.events
  'click a[data-action=removeAttachment]': (e, tpl) ->
    data = { attachmentId: this.valueOf(), ticketId: tpl.data._id }
    Blaze.renderWithData(Template['removeAttachmentModal'], data, $('body').get(0))
    $('#removeAttachmentModal').modal('show')

  'keyup input[name=addTag]': (e, tpl) ->
    if e.which is 13
      val = $(e.target).val()?.split(' ')
      Tickets.update tpl.data._id, {$addToSet: {tags: $each: val}}
      $(e.target).val('')
  'keyup input[name=assignUser]': (e, tpl) ->
    if e.which is 13
      id = Meteor.call 'checkUsername', $(e.target).val(), (err, res) ->
        if res
          tpl.$('[data-toggle="tooltip"]').tooltip('hide')
          Tickets.update tpl.data._id, {$addToSet: {associatedUserIds: res}}
          $(e.target).val('')
        else
          tpl.$('[data-toggle="tooltip"]').tooltip('show')
  ### Uploading files. ###
  'click a[data-action=uploadFile]': (e, tpl) ->
    Media.pickLocalFile (fileId) ->
      console.log "Uploaded a file, got _id: ", fileId
      Tickets.update tpl.data._id, {$addToSet: {attachmentIds: fileId}}
      Meteor.call 'setFlag', Meteor.userId(), tpl.data._id, 'attachment', true

Template.ticketNoteInput.helpers
  settings: ->
    {
      position: "top"
      limit: 5
      rules: [
        {
          token: '@'
          collection: Meteor.users
          field: 'username'
          template: Template.userPill
        }
        {
          token: '#'
          collection: Tags
          field: 'name'
          template: Template.tagPill
          noMatchTemplate: Template.noMatchTagPill
        }
      ]
    }


Template.ticketNoteInput.events
  ### Uploading files. ###
  'click a[data-action=uploadFile]': (e, tpl) ->
    Media.pickLocalFile (fileId) ->
      console.log "Uploaded a file, got _id: ", fileId
      Tickets.update tpl.data.ticket, {$addToSet: {attachmentIds: fileId}}
      Meteor.call 'setFlag', Meteor.userId(), tpl.data.ticket, 'attachment', true

  ### Adding notes to tickets. ###
  'keyup input[name=newNoteAdmin]': (e, tpl) ->
    if (e.which is 13) and (e.target.value isnt "")
      body = e.target.value
      hashtags = getTags body
      users = getUserIds body
      status = getStatuses body
      if status?.length > 0
        Tickets.update tpl.data.ticket, {$set: {status: status[0]}} #If multiple results, just use the first.

      if users?.length > 0
        Tickets.update tpl.data.ticket, {$addToSet: {associatedUserIds: $each: users}}

      if hashtags?.length > 0
        Tickets.update tpl.data.ticket, {$addToSet: {tags: $each: hashtags}}

      Changelog.insert
        ticketId: tpl.data.ticket
        timestamp: new Date()
        authorId: Meteor.userId()
        authorName: Meteor.user().username
        type: "note"
        message: e.target.value

      Meteor.call 'setFlag', Meteor.userId(), tpl.data.ticket, 'replied', true

      $(e.target).val("")

  'keyup input[name=newNote]': (e, tpl) ->
    if (e.which is 13) and (e.target.value isnt "")
      Changelog.insert
        ticketId: tpl.data.ticket
        timestamp: new Date()
        authorId: Meteor.userId()
        authorName: Meteor.user().username
        type: "note"
        message: e.target.value

      Meteor.call 'setFlag', Meteor.userId(), tpl.data.ticket, 'replied', true
      $(e.target).val("")
    
Template.ticketTag.events
  'click a[data-action=removeTag]': (e, tpl) ->
    e.preventDefault()
    ticketId = Template.parentData(1)._id
    Tickets.update {_id: ticketId}, {$pull: {tags: this.valueOf()}}
  
  'click a[data-action=addTagFilter]': (e, tpl) ->
    e.preventDefault()
    value = this.valueOf()
    filter = Iron.query.get('tag')?.split(',') || []
    unless filter.indexOf(value) > -1
      filter.push(value)
    Iron.query.set 'tag', filter.join()

Template.ticketHeading.helpers
  author: ->
    Meteor.users.findOne {_id: @authorId}
