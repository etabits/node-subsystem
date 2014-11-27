mongoose	= require('mongoose')

schema = mongoose.Schema {
	date:	Date
	key:	String
	#expired: {type: Boolean, default: false}
	meta:	Object
	type:	String
}

Model = mongoose.model('Reset', schema)

module.exports = Model