

subsystem = module.exports = {
	UserForms: require('./user/forms')
	Mailer: {
		Mandrill: require('./mailer/mandrill')
	}
	helpers: require('./helpers')
	ResetKeyring: require('./reset_keyring/')
}
