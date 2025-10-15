// Firebase configuration for Firestore
import { initializeApp } from 'firebase/app';
import { getFirestore, connectFirestoreEmulator } from 'firebase/firestore';
import { getAuth, connectAuthEmulator } from 'firebase/auth';
import { getStorage, connectStorageEmulator } from 'firebase/storage';

const firebaseConfig = {
    apiKey: "AIzaSyAa-268Fx-XfJTsJLGznwcztd82r2vdf3Q",
    authDomain: "marketsafe-e57cf.firebaseapp.com",
    projectId: "marketsafe-e57cf",
    storageBucket: "marketsafe-e57cf.firebasestorage.app",
    messagingSenderId: "744810618140",
    appId: "1:744810618140:web:1b333167538cf6d957aed9"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);

// Initialize Firestore
export const db = getFirestore(app);

// Initialize Auth
export const auth = getAuth(app);

// Initialize Storage
export const storage = getStorage(app);

// Connect to emulators in development (uncomment for local development)
// if (location.hostname === 'localhost') {
//     connectFirestoreEmulator(db, 'localhost', 8080);
//     connectAuthEmulator(auth, 'http://localhost:9099');
//     connectStorageEmulator(storage, 'localhost', 9199);
// }

export default app;



