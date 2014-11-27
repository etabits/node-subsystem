mandrill = require('mandrill-api/mandrill')


class Mandrill
	self = null

	constructor: (@opts) ->
		self = this
		@client = new mandrill.Mandrill(@opts.apiKey)
		#console.log 'apiKey:', @opts.apiKey

	send: (template, metas, vars, done)->
		global_merge_vars = []
		for name, value of vars
			global_merge_vars.push {name:name, content: value}
			
		sendObj = {
				"template_name": template,
				"template_content": [],
				"message": {
					"to": [{
							"name": metas.to[0]
							"email": metas.to[1]
							"type": "to"
						}],
					"merge": true,
					"global_merge_vars": global_merge_vars,

				}

			}
		console.log 'Sending ', sendObj, sendObj.message
		#return

		self.client.messages.sendTemplate sendObj, (result)->
				console.log('Mandrill Sent', result)
				done(null, result)
			, (e)->
				console.log('Mandrill Error', e)
				done(e)

module.exports = Mandrill