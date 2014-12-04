_ = require 'lodash'
forms = require 'forms'
fields = forms.fields
validators = forms.validators
async = require 'async'
mongoose = require 'mongoose'

helpers = require '../helpers'
{EventEmitter} = require 'events'

defaults = {
  pathSettings: {
    type: 'update'
    middlewares: []
    fields: []
  }
  opts: {
    formCreateOptions: {validatePastFirstError: true}
    emailTemplates: {}
  }
  fields: {
    #reset_email: 

    email2:  fields.email({
      required: validators.required('Please confirm your email')
      validators: [validators.matchField('email')]
      label: 'Confirm Email'

    })
    email2_change:  fields.email({
      required: validators.required('Please confirm your email')
      validators: [validators.matchField('new_email')]
      label: 'Confirm Email'

    })
    password2:  fields.password({
      required: validators.required('Please confirm your password')
      validators: [validators.matchField('password')]
      label: 'Confirm Password'

    })
    old_password:  fields.password({
      required: validators.required('Please enter your old password')
      label: 'Old Password'

    })
  }
}

class UserForms extends EventEmitter
  self = null

  ## Instantiation
  constructor: (@opts) ->
    self = this
    @opts = _.merge {}, defaults.opts, @opts
    @User = @opts.model

    @fields = _.merge {}, defaults.fields, @opts.fields

    @pathSettingsDefaults = _.merge {}, defaults.pathSettings #, {tpl: @opts.defaultTemplate}
    for path, pathSettings of @opts.paths
      pathSettings.path = path
      pathSettings = _.merge {}, @pathSettingsDefaults, pathSettings
      pathSettings.formFields = {}
      pathSettings.formFields[fieldName] = @fields[fieldName] for fieldName in pathSettings.fields

      # User or Visitor?
      pathSettings.loggedIn = -1 == ['register','reset'].indexOf(pathSettings.type)
      # Correct middlewares
      pathSettings.middlewares.push if pathSettings.loggedIn then helpers.mw.loggedIn else helpers.mw.notLoggedIn
      pathSettings.tpl ?= if pathSettings.loggedIn then @opts.defaultUserTemplate else @opts.defaultVisitorTemplate

      switch pathSettings.type
        when 'password'
          pathSettings.formFields = {
            old_password: @fields['old_password']
            password:  @fields['password']
            password2: @fields['password2']
          }
        when 'email'
          pathSettings.formFields = {
            new_email:  @fields['email']
            email2: @fields['email2_change']
          }
        when 'reset'
          pathSettings.formFields = {
            email:  fields.email({ required: true, validators: [helpers.createDbFieldValidator(mongoose.model('User'), 'email', true)]})
          }

          
      pathSettings.form = forms.create pathSettings.formFields, @opts.formCreateOptions

      pathSettings.responder = self.createResponder(pathSettings)

      @opts.paths[path] = pathSettings

  sendVerificationEmail: (user, done)->
    self.opts.resetKeyring.createKey 'verify', {email: user.email, user: user._id}, (err, verificationKey)->
      self.opts.mailer.send self.opts.emailTemplates['activation'], {
          to: [user.name, user.email]
        }, {
          FIRSTNAME: user.name.split(' ')[0]
          URLPREFIX: self.opts.resetKeyring.types['verify']
          ACTIVATION_KEY: verificationKey.key
        }, ()->
          console.log '>>>>>>>', arguments
          

  setupApp: (app) ->
    self.app = app
    for path, pathSettings of self.opts.paths
      app.get path, pathSettings.middlewares, pathSettings.responder
      app.post path, pathSettings.middlewares, pathSettings.responder


    if self.opts.emailTemplates['activation']
      #console.log self.opts.emailTemplates['activation']
      self.on 'registration', (user)-> self.sendVerificationEmail(user)


  createResponder: (pathSettings)->
    autoResponderSettings = {
      form: pathSettings.form
      tpl: pathSettings.tpl
      locals: {
        title: 'Account'
        userFormsPathSettings: pathSettings
      }
    }
    switch pathSettings.type
      when 'update'
        (req, res, next)->
          autoResponderSettings.doc = req.user
          autoResponderSettings.successMessage = 'Your account was updated successfully.'

          helpers.autoFormRespond req, res, autoResponderSettings

      when 'register'
        (req, res, next)->
          autoResponderSettings.successCb = (form)->
            u = new self.User(form.data)
            #u.unverifiedEmail = u.email
            #u.email = ''
            u.save (err)->
              return next(err) if err
              self.emit 'registration', u
              return self.opts.registrationHandler(req, res, next, u, form)

            #console.log
          helpers.autoFormRespond req, res, autoResponderSettings

      when 'reset'
        (req, res, next)->
          autoResponderSettings.successCb = (form)->
            self.User.findOne {email: form.data.email}, (err, user)->
              self.opts.resetKeyring.createKey 'reset', {email: user.email, user: user._id}, (err, resetKey)->
                self.opts.mailer.send self.opts.emailTemplates['reset'], {
                    to: [user.name, user.email]
                  }, {
                    FIRSTNAME: user.name.split(' ')[0]
                    URLPREFIX: self.opts.resetKeyring.types['reset']
                    RESET_KEY: resetKey.key
                  }, ()->
                    req.flash 'messages', {type: 'success', body: 'An email to reset your password has been sent to you.'}
                    res.redirect '/'

          helpers.autoFormRespond req, res, autoResponderSettings

      when 'email'
        (req, res, next)->
          autoResponderSettings.successCb = (form)->
            console.log form.data
            #req.user.email = ''
            req.user.email = form.data['new_email']
            req.user.emailVerified = false
            req.user.save (err)->
              if err
                return next(err)
              else
                self.sendVerificationEmail(req.user)
                req.flash 'messages', {
                  type: 'success'
                  body: 'Your email was changed successfully. Your new email is unverified until you click the link sent to your new email address. Please start to use the new address to login.'
                }
              res.redirect req.originalUrl

          helpers.autoFormRespond req, res, autoResponderSettings

      when 'password'
        (req, res, next)->
          autoResponderSettings.successCb = (form)->
            #console.log form.data
            req.user.changePassword form.data['old_password'], form.data['password'], (err)->
              if err
                if 'subsystem' == err.source # our error
                  req.flash 'messages', {
                    type: 'danger'
                    body: err.message
                  }
                  res.locals.form = form
                  #res.render autoResponderSettings.tpl, autoResponderSettings.locals
                else return next(err)
              else
                req.flash 'messages', {
                  type: 'success'
                  body: 'Your password was changed successfully!'
                }
                self.emit 'passwordchange', req.user
              res.redirect req.originalUrl



          helpers.autoFormRespond req, res, autoResponderSettings


      else (req, res, next)-> res.send(501)


module.exports = UserForms