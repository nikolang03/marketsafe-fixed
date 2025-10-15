const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

admin.initializeApp();

// Email OTP storage (in production, use Firestore)
const emailOtps = new Map();

// Create transporter for sending emails
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: 'kincunanan33@gmail.com',
    pass: 'urif udrb lkuq xkgi'
  }
});

exports.sendEmailOtp = functions.https.onCall(async (data, context) => {
  const { email } = data;
  
  if (!email) {
    throw new functions.https.HttpsError('invalid-argument', 'Email is required');
  }

  // Generate 6-digit OTP
  const otp = Math.floor(100000 + Math.random() * 900000).toString();
  
  // Store OTP with expiration (5 minutes)
  emailOtps.set(email, {
    otp: otp,
    expires: Date.now() + 5 * 60 * 1000 // 5 minutes
  });

  // Email content
  const mailOptions = {
    from: 'kincunanan33@gmail.com',
    to: email,
    subject: 'MarketSafe Verification Code',
    text: `Your verification code is: ${otp}\n\nThis code will expire in 5 minutes.`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #d32f2f;">MarketSafe Verification Code</h2>
        <p>Your verification code is:</p>
        <div style="background-color: #f5f5f5; padding: 20px; text-align: center; margin: 20px 0;">
          <h1 style="color: #d32f2f; font-size: 32px; margin: 0; letter-spacing: 5px;">${otp}</h1>
        </div>
        <p>This code will expire in 5 minutes.</p>
        <p>If you didn't request this code, please ignore this email.</p>
      </div>
    `
  };

  try {
    await transporter.sendMail(mailOptions);
    console.log(`OTP sent to ${email}: ${otp}`);
    return { success: true };
  } catch (error) {
    console.error('Error sending email:', error);
    throw new functions.https.HttpsError('internal', 'Failed to send email');
  }
});

exports.verifyEmailOtp = functions.https.onCall(async (data, context) => {
  const { email, code } = data;
  
  if (!email || !code) {
    throw new functions.https.HttpsError('invalid-argument', 'Email and code are required');
  }

  const storedOtp = emailOtps.get(email);
  
  if (!storedOtp) {
    return { success: false, message: 'No OTP found for this email' };
  }

  if (Date.now() > storedOtp.expires) {
    emailOtps.delete(email);
    return { success: false, message: 'OTP has expired' };
  }

  if (storedOtp.otp !== code) {
    return { success: false, message: 'Invalid OTP code' };
  }

  // OTP is valid, remove it
  emailOtps.delete(email);
  return { success: true };
});