{EventEmitter} = require 'events'
crypto = require('crypto')
Reset = require('./reset')
mongoose = require 'mongoose'

class ResetKeyring extends EventEmitter
  self = null

  ## Instantiation
  constructor: (@opts) ->
    @types = @opts.types
    self = this


  setupApp: (@app) ->
    app.param 'reset_key', (req, res, next)->
      Reset.findOne {key: req.params.reset_key}, (err, result)->
        return next(err) if err
        return res.send(404) if not result
        req.resetKey = result
        next()

    self.on 'request-verify', (req, res, next)->
      mongoose.model('User').findOne {_id: req.resetKey.meta.user, email: req.resetKey.meta.email}, (err, user)->
        return next(err) if err
        return res.send(404) if not user
        #user.email = user.unverifiedEmail
        user.emailVerified = true
        user.save()
        req.resetKey.remove()
        req.flash('messages', {type: 'success', body: 'Thank you, your email has now been verified.'})
        res.redirect '/account/'

    self.on 'request-reset', (req, res, next)->
      mongoose.model('User').findOne {_id: req.resetKey.meta.user, email: req.resetKey.meta.email}, (err, user)->
        return next(err) if err
        return res.send(404) if not user
        #user.email = user.unverifiedEmail
        crypto.randomBytes 6, (ex, buf)->
          newPassword = buf.toString('hex').toUpperCase()
          user.password = newPassword
          #console.log newPassword
          user.save()
          self.opts.mailer.send 'new-password', {
              to: [user.name, user.email]
            }, {
              FIRSTNAME: user.name.split(' ')[0]
              NEW_PASSWORD: newPassword
            }, ()->
              req.flash('messages', {type: 'success', body: 'A new password was sent to your email.'})
              res.redirect '/login'
              #console.log(req.resetKey, user, newPassword); return;
              #req.resetKey.remove()


      console.log req.resetKey
        

    for type, path of self.types
      @app.get "/#{path}/:reset_key",  (req, res, next)->
        self.emit "request-#{req.resetKey.type}", req, res, next
      #console.log type, path


  createKey: (type, meta, done) ->
    crypto.randomBytes 16, (ex, buf)->
      d = new Reset()
      d.date = new Date()
      d.key = buf.toString('hex')
      d.meta = meta
      d.type = type
      d.save (err, result)-> done(err, result) # don't ask why...




module.exports = ResetKeyring