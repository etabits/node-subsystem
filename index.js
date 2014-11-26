
try { // Development time...
	require('coffee-script/register')
	module.exports = require('./src/')
} catch (e) {
	//console.log('Falling back to the compiled javascript version', e.message, e)
	module.exports = require('./lib/')
}
