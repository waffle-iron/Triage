@Tickets = new Mongo.Collection 'tickets'
@Tickets.attachSchema new SimpleSchema
  title:
    label: "Title"
    type: String
  body:
    label: "Body"
    type: String
  formFields:
    label: "Form Fields"
    type: Object
    blackbox: true
    optional: true
  authorId:
    type: String
  authorName:
    type: String
  status:
    type: String
    defaultValue: 'Open'
  tags:
    optional: true
    type: [String]
  submissionData:
    type: Object
    optional: true
  'submissionData.method':
    optional: true
    type: String
    allowedValues: ['Web', 'Email', 'Form', 'Mobile']
  'submissionData.ipAddress':
    optional: true
    type: String
  'submissionData.hostname':
    optional: true
    type: String
  submittedTimestamp:
    type: new Date()
    defaultValue: Date.now
  closedTimestamp:
    optional: true
    type: new Date()
  queueName:
    type: String
  associatedUserIds:
    optional: true
    type: [String]
  attachmentIds:
    optional: true
    type: [String]
  ticketNumber:
    type: Number
    unique: true
    optional: true

if Meteor.isServer && Npm.require('cluster').isMaster
  Tickets.before.insert (userId, doc) ->
    max = Tickets.findOne({}, {sort:{ticketNumber:-1}})?.ticketNumber || 0
    doc.ticketNumber = max + 1
    doc.timestamp = new Date()

  Tickets.before.update (userId, doc, fieldNames, modifier, options) ->
    _.each fieldNames, (fn) ->
      switch fn
        when 'tags'
          if modifier.$addToSet?.tags?
            tags = _.difference modifier.$addToSet.tags.$each, doc.tags
            message = "added tag(s) #{tags}"
          if modifier.$pull?.tags?
            message = "removed tag(s) #{modifier.$pull.tags}"
        when 'status'
          message = "changed status from #{doc.status} to #{modifier.$set.status}"
        when 'associatedUserIds'
          if modifier.$addToSet?.associatedUserIds?
            users = _.map modifier.$addToSet.associatedUserIds.$each, (x) ->
              Meteor.users.findOne({_id: x}).username
            message = "associated user(s) #{users}"
          if modifier.$pull?.associatedUserIds?
            user = Meteor.users.findOne({_id: modifier.$pull.associatedUserIds}).username
            message = "disassociated user #{user}"
      Changelog.insert
        ticketId: doc._id
        timestamp: new Date()
        authorId: Meteor.userId()
        authorName: Meteor.user().username
        type: "field"
        field: fn
        message: message

@TicketFlags = new Mongo.Collection 'ticketFlags'
# TODO: SimpleSchema doesnt handle v very well, so skip for now
###@TicketFlags.attachSchema new SimpleSchema
  userId:
    type: String
  ticketId:
    type: String
  k:
    type: String
  v:
    type: Object
    blackbox: true
###

@Changelog = new Mongo.Collection 'changelog'
@Changelog.attachSchema new SimpleSchema
  ticketId:
    type: String
    label: "Ticket ID"
  timestamp:
    type: new Date()
    label: "Timestamp"
  authorId:
    type: String
    label: "Author ID"
  authorName:
    type: String
    label: "Author Name"
  type:
    type: String
    allowedValues: ['note', 'field', 'attachment']
    label: "Type"
  field:
    type: String
    label: "Field"
    optional: true
  message:
    type: String
    label: "Message"
    optional: true
  otherId:
    type: String
    optional: true

if Meteor.isServer
  Changelog.before.insert (userId, doc) ->
    doc.timestamp = new Date()

@Queues = new Mongo.Collection 'queues'
@Queues.attachSchema new SimpleSchema
  name:
    type: String
    label: "Name"
  memberIds:
    type: [String]
    label: "Queue Members"
    optional: true
  securityGroups:
    type: [String]
    label: "Security Groups"
