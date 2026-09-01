const nodemailer = require('nodemailer');

let transporter;

function mailConfig(){
  const user = process.env.ROWTRAINING_GMAIL_USER;
  const pass = String(process.env.ROWTRAINING_GMAIL_APP_PASSWORD || '').replace(/\s+/g,'');
  if(!user || !pass){
    const err = new Error('Faltan ROWTRAINING_GMAIL_USER o ROWTRAINING_GMAIL_APP_PASSWORD en Vercel.');
    err.code = 'gmail_not_configured';
    throw err;
  }
  return {user, pass};
}

function getTransporter(){
  if(transporter) return transporter;
  const {user, pass} = mailConfig();
  transporter = nodemailer.createTransport({
    host: 'smtp.gmail.com',
    port: 465,
    secure: true,
    auth: {user, pass},
    connectionTimeout: 10000,
    greetingTimeout: 10000,
    socketTimeout: 20000,
    pool: true,
    maxConnections: 2,
    maxMessages: 50
  });
  return transporter;
}

async function sendRowTrainingMail({to, subject, html, text, replyTo}){
  const {user} = mailConfig();
  const tx = getTransporter();
  return tx.sendMail({
    from: `Row Training <${user}>`,
    to,
    replyTo: replyTo || user,
    subject,
    html,
    text: text || undefined
  });
}

module.exports = {sendRowTrainingMail};
