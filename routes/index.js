/* eslint-disable no-multi-spaces */
const express = require('express')
const router  = express.Router()
// const pki = require('node-forge').pki
// const rsa = pki.rsa
const fs = require('fs')
const CERT_PATH = require('../config/certGen').CERT_PATH

/* GET home page. */
router.get('/', function (req, res, next) {
  res.render('index', {title: 'Beautiful App'})
})

// router.get('/crash', function (req, res, next) {
//   console.log(new Error('Requested crash by endpoint /crash'))
//   process.exit(1)
// })

// TODO: is not optimized and creates resource consumption peaks
// router.get('/generatecert', function (req, res, next) {
//   const keys = pki.rsa.generateKeyPair(2048)
//   const cert = pki.createCertificate()
//   cert.publicKey = keys.publicKey
//   res.send({
//     keys: keys,
//     cert: cert
//   })
// })

// Still too slow
// router.get('/generatecert', function (req, res, next) {
//   rsa.generateKeyPair({bits: 2048, workers: -1}, function (_err, keypair) {
//     const cert = pki.createCertificate()
//     cert.publicKey = keypair.publicKey
//     res.send({
//       keys: keypair,
//       cert: cert
//     })
//   })
// })

router.get('/generatecert', function (req, res, next) {
  const key  = fs.readFileSync(CERT_PATH + 'localhost.key')
  const cert = fs.readFileSync(CERT_PATH + 'localhost.cert')
  res.send({
    keys: key,
    cert: cert
  })
})

module.exports = router
