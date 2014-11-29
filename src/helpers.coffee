_ = require 'lodash'
helpers = {}
bcrypt = require('bcrypt')

helpers.doUserSchema = (userSchema, opts)->

	userSchema.methods.changePassword = (oldPass, newPass, done)->
		#return done(null, false, {message: "MIN_LENGTH"}) if newPass.length < opts.minPassLength
		self = this
		self.validPassword oldPass, (err, match)->
			return done(err) if err
			return done({source: 'subsystem', message: 'Bad Password'}) if not match
			console.log arguments
			self.password = newPass
			self.save (err)->
				return done(err) if err
				return done(null, true)

	userSchema.methods.validPassword = (password, done)->
		if done
			bcrypt.compare(password, this.password, done)
		else
			return bcrypt.compareSync(password, this.password)

	userSchema.pre 'save', (next)->
		user = this
		return next() unless user.isModified('password')
		bcrypt.genSalt (err, salt)->
			return next(err) if err
			bcrypt.hash user.password, salt, (err, hash)->
				return next(err) if err
				user.password = hash
				next()


helpers.createDbFieldValidator = (model, fieldName, shouldExist, errorMessage)->
	shouldExist ?= false
	#shouldExist ?= true
	errorMessage ?= if shouldExist then "No such #{fieldName} in our database" else "#{fieldName} already present in the database"
	(fform, field, cb)->
		#console.log fform
		fieldValue = field.data
		query = {}
		query[fieldName] = fieldValue

		model.findOne query, (err, doc) ->
			#console.log doc, shouldExist
			error = !doc == shouldExist
			field._foundDocument = doc
			if error
				cb(errorMessage)
			else
				cb()

helpers.autoFormRespond = (req, res, opts)->
	res.locals.messages = req.flash('messages')
	theForm = opts.form

	theForm.handle req, {
		success: (form)->
			return opts.successCb(form) if opts.successCb

			for k,v of form.data
				opts.doc[k]=v
			opts.doc.save ()->
				if opts.finishedCb
					opts.finishedCb()
				else
					req.flash 'messages', {
						type: 'success'
						body: opts.successMessage
					}
					res.redirect req.originalUrl



		error: (form) ->
			res.render opts.tpl, _.merge({}, opts.locals, {form: form})

		empty: () ->

			res.locals.form = if opts.doc then theForm.bind(opts.doc.toObject()) else theForm
			
			#console.log nform
			#console.log opts.doc, opts.doc.values, nform
			res.render opts.tpl, opts.locals
	}

helpers.mw = {}
helpers.mw.loggedIn = (req, res, next)->
	return next() if req.isAuthenticated()
	res.redirect('/login')

helpers.mw.notLoggedIn = (req, res, next)->
	return next() if not req.isAuthenticated()
	res.redirect('/home')


module.exports = helpers