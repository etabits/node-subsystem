_ = require 'lodash'
forms = require 'forms'
fields = forms.fields
validators = forms.validators


helpers = require './helpers'


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

class UserForms
	self = null

	## Instantiation
	constructor: (@opts) ->
		self = this
		@opts = _.merge {}, defaults.opts, @opts
		@User = @opts.model

		@fields = _.merge {}, defaults.fields, @opts.fields

		@pathSettingsDefaults = _.merge {}, defaults.pathSettings, {tpl: @opts.defaultTemplate}
		for path, pathSettings of @opts.paths
			pathSettings = _.merge {}, @pathSettingsDefaults, pathSettings
			pathSettings.formFields = {}
			pathSettings.formFields[fieldName] = @fields[fieldName] for fieldName in pathSettings.fields

			# Correct middlewares
			pathSettings.middlewares.push switch pathSettings.type
				when 'register' then helpers.mw.notLoggedIn
				else helpers.mw.loggedIn

			switch pathSettings.type
				when 'password'
					pathSettings.formFields = {
						old_password: @fields['old_password']
						password: @fields['password']
						password2: @fields['password2']
					}
					
			pathSettings.form = forms.create pathSettings.formFields, @opts.formCreateOptions

			pathSettings.responder = self.createResponder(pathSettings)

			@opts.paths[path] = pathSettings

	setupApp: (app) ->
		self.app = app
		for path, pathSettings of self.opts.paths
			app.get path, pathSettings.middlewares, pathSettings.responder
			app.post path, pathSettings.middlewares, pathSettings.responder
		#d()

	createResponder: (pathSettings)->
		autoResponderSettings = {
			form: pathSettings.form
			tpl: pathSettings.tpl
			locals: {
				title: 'Account'
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
							return self.opts.registrationHandler(req, res, next, u, form)

						#console.log 
					helpers.autoFormRespond req, res, autoResponderSettings

			when 'password'
				(req, res, next)->
					autoResponderSettings.successCb = (form)->
						console.log form.data
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
							res.redirect ''



					helpers.autoFormRespond req, res, autoResponderSettings


			else (req, res, next)-> res.send(501)




subsystem = module.exports = {
	UserForms: UserForms
	helpers: helpers
}