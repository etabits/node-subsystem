_ = require 'lodash'
forms = require 'forms'
fields = forms.fields
validators = forms.validators
async = require 'async'

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
  }
  fields: {

    email2:  fields.email({
      required: validators.required('Please confirm your email')
      validators: [validators.matchField('email')]
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
            email:  @fields['email']
            email2: @fields['email2']
          }
          
      pathSettings.form = forms.create pathSettings.formFields, @opts.formCreateOptions

      pathSettings.responder = self.createResponder(pathSettings)

      @opts.paths[path] = pathSettings

  sendVerificationEmail: (user, done)->
    self.opts.resetKeyring.createKey 'verify', {email: user.unverifiedEmail, user: user._id}, (err, verificationKey)->
      self.opts.mailer.send self.opts.emailActivationTemplate, {
          to: [user.name, user.unverifiedEmail]
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


    if self.opts.emailActivationTemplate
      #console.log self.opts.emailActivationTemplate
      self.on 'registration', (user)->
        user.unverifiedEmail = user.email
        user.email = ''
        user.save ()->
          self.sendVerificationEmail(user)


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
            u.save (err)->
              return next(err) if err
              self.emit 'registration', u
              return self.opts.registrationHandler(req, res, next, u, form)

            #console.log
          helpers.autoFormRespond req, res, autoResponderSettings

      when 'email'
        (req, res, next)->
          autoResponderSettings.successCb = (form)->
            console.log form.data
            req.user.email = form.data['email']
            req.user.emailVerified = false
            req.user.save (err)->
              if err
                return next(err)
              else
                req.flash 'messages', {
                  type: 'success'
                  body: 'Your email was changed successfully!'
                }
              res.redirect ''

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
              res.redirect ''



          helpers.autoFormRespond req, res, autoResponderSettings


      else (req, res, next)-> res.send(501)


module.exports = UserForms