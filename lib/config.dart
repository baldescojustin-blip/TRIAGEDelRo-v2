// config.dart
//
// Single source of truth for the backend API base URL. Every screen/service
// that talks to the FastAPI backend should import this instead of hardcoding
// its own copy of the URL — that way switching between local development and
// a deployed backend only requires changing it in one place.

const String kApiBaseUrl = 'https://jus1012-triage-delro-api.hf.space';
