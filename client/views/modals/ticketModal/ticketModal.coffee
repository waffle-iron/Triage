Template.ticketModal.events
  'hidden.bs.modal': (e, tpl) ->
    Blaze.remove tpl.view

  'click a[name=ticketLink]': (e, tpl) ->
    # Have to hide the modal manually when clicking the direct link to the ticket page. Could do away with
    # the whole 'ticket page' concept and have those routes point to the queue + modal?
    tpl.$('#ticketModal').modal('hide')

Template.ticketModal.helpers
  bodyParagraph: ->
    @body.split('\n')


Template.ticketModal.onCreated ->
  Meteor.subscribe 'ticketSupplement', this.data._id
