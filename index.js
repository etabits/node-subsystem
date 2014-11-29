var coffeeScriptAvailable = true;

try { // Development time...
	require('coffee-script/register')
} catch (e) {
	coffeeScriptAvailable = false;
	//console.log('Falling back to the compiled javascript version', e.message, e.stack, e)
}

module.exports = require(coffeeScriptAvailable? './src/': './lib/')