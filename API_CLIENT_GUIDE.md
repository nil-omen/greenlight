# Greenlight API Client Guide

This document provides a comprehensive guide for building a client application (CLI, Web, or Mobile) that interacts with the Greenlight API.

## Table of Contents
- [Authentication & Tokens](#authentication--tokens)
- [General JSON Formats](#general-json-formats)
- [Error Handling](#error-handling)
- [Endpoints Overview](#endpoints-overview)
- [Movies API (Examples & Search)](#movies-api-examples--search)
- [Users API](#users-api)
- [Tokens API](#tokens-api)

---

## Authentication & Tokens

The Greenlight API relies on token-based authentication. Client applications must pass a valid Bearer token in the `Authorization` header for protected routes.

**Header Format:**
```http
Authorization: Bearer <token>
```

**Token Scopes & Lifespans:**
There are three types of tokens issued by the API:
1. **Authentication Token (`authentication`)**: Lasts for 24 hours. Given upon successful login. Requires the user to be activated.
2. **Activation Token (`activation`)**: Lasts for 3 days. Sent to the user's email upon registration to activate their account.
3. **Password Reset Token (`password-reset`)**: Lasts for 45 minutes. Sent to the user's email when requesting a password reset.

## General JSON Formats

The API uses "envelopes" for all JSON responses. This means the actual data is wrapped in a top-level JSON object with a descriptive key, such as `{"movie": {...}}` or `{"error": "..."}`.

### Custom Types
**Runtime:** 
Always provided and expected as a string with the suffix `" mins"`. 
*Example:* `"105 mins"` (not an integer like `105`).

**Dates:** 
Timestamps (like `created_at`) are returned in RFC3339 format, but are generally excluded from request bodies.

---

## Error Handling

All errors are returned with the appropriate HTTP Status Code and a JSON envelope structured with an `"error"` key.

**Typical Error Formats:**
- **Standard Error:** 
  ```json
  { "error": "the requested resource could not be found" }
  ```
- **Validation Error (HTTP 422 Unprocessable Entity):** 
  Validation errors return a map of the fields that failed validation and their respective error messages.
  ```json
  {
    "error": {
        "title": "must be provided",
        "genres": "must contain at least 1 genre",
        "runtime": "invalid runtime format"
    }
  }
  ```

**Common Status Codes & Meanings:**
- `400 Bad Request`: Invalid JSON payload or parameters.
- `401 Unauthorized`: Missing or invalid authentication token. OR invalid email/password during login.
- `403 Forbidden`: Account not activated, or lack of permissions (e.g., trying to modify a movie without `movies:write` permission).
- `404 Not Found`: Endpoint or requested resource (e.g., Movie ID) doesn't exist.
- `405 Method Not Allowed`: HTTP method not supported for this endpoint.
- `409 Conflict`: Attempted to update a record that was modified by another client simultaneously (Edit Conflict).
- `422 Unprocessable Entity`: Request payload failed validation checks.
- `429 Too Many Requests`: Rate limit exceeded.
- `500 Internal Server Error`: Server encountered a problem.

---

## Endpoints Overview

| Method | Path | Required Permission | Description |
|--------|------|---------------------|-------------|
| GET | `/v1/healthcheck` | *None* | System status |
| GET | `/v1/movies` | `movies:read` | List/Search movies (paginated) |
| POST | `/v1/movies` | `movies:write` | Create a new movie |
| GET | `/v1/movies/:id` | `movies:read` | Get movie details |
| PATCH | `/v1/movies/:id` | `movies:write` | Update movie details |
| DELETE | `/v1/movies/:id` | `movies:write` | Delete a movie |
| POST | `/v1/users` | *None* | Register a new user |
| PUT | `/v1/users/activated` | *None* | Activate a user account |
| PUT | `/v1/users/password` | *None* | Reset a user's password |
| POST | `/v1/tokens/authentication` | *None* | Login (Get Auth Token) |
| POST | `/v1/tokens/activation` | *None* | Request Activation Token |
| POST | `/v1/tokens/password-reset` | *None* | Request Password Reset Token |

*Note: All protected endpoints require the client to include the `Authorization: Bearer <token>` header.*

---

## Movies API (Examples & Search)

### 1. Create a Movie
**`POST /v1/movies`**

**Request Payload:**
```json
{
    "title": "Moana",
    "year": 2016,
    "runtime": "107 mins",
    "genres": ["animation", "adventure"]
}
```
**Response (201 Created):**
```json
{
    "movie": {
        "id": 1,
        "title": "Moana",
        "year": 2016,
        "runtime": "107 mins",
        "genres": ["animation", "adventure"],
        "version": 1
    }
}
```

### 2. Search & List Movies (Pagination)
**`GET /v1/movies`**

Supports extensive query parameters for filtering, sorting, and pagination.

**Query Parameters:**
- `title` (string): Search for part of a title. (e.g., `?title=moana`)
- `genres` (string): Comma-separated list to filter by exact genre matches. (e.g., `?genres=animation,adventure`)
- `page` (int, default 1): Page number to retrieve.
- `page_size` (int, default 20): Number of records per page.
- `sort` (string, default `id`): Sort by a field. Use `-` for descending. (Valid: `id`, `title`, `year`, `runtime`, `-id`, `-title`, `-year`, `-runtime`).

**Example Request:**
`GET /v1/movies?title=black&genres=action&page=1&page_size=5&sort=-year`

**Response (200 OK):**
```json
{
    "metadata": {
        "current_page": 1,
        "page_size": 5,
        "first_page": 1,
        "last_page": 2,
        "total_records": 9
    },
    "movies": [
        {
            "id": 12,
            "title": "Black Panther",
            "year": 2018,
            "runtime": "134 mins",
            "genres": ["action", "adventure"],
            "version": 1
        }
    ]
}
```

### 3. Update a Movie
**`PATCH /v1/movies/:id`**

Supports partial updates. Only send the fields you want to change.

**Request Payload:**
```json
{
    "year": 2017,
    "runtime": "110 mins"
}
```

---

## Users API

### 1. Register a User
**`POST /v1/users`**
Creates an unactivated user and sends an email with an activation token.

**Request Payload:**
```json
{
    "name": "Alice Smith",
    "email": "alice@example.com",
    "password": "password123"
}
```

### 2. Activate a User
**`PUT /v1/users/activated`**
Activates the user using the token sent via email.

**Request Payload:**
```json
{
    "token": "U4C2XZYX3T... (26 char plain text token)"
}
```

### 3. Reset Password
**`PUT /v1/users/password`**
Resets the password using the token sent to the user's email.

**Request Payload:**
```json
{
    "password": "newpassword123",
    "token": "U4C2XZYX3T... (26 char plain text token)"
}
```

---

## Tokens API

### 1. Login (Create Authentication Token)
**`POST /v1/tokens/authentication`**

**Request Payload:**
```json
{
    "email": "alice@example.com",
    "password": "password123"
}
```
**Response (201 Created):**
```json
{
    "authentication_token": {
        "token": "U4C2XZYX3T...",
        "expiry": "2026-03-27T10:00:00Z"
    }
}
```
*(The `token` value here is what your client must store and use in the `Authorization` header).*

### 2. Request Activation Email
**`POST /v1/tokens/activation`**
Resends the activation token email to an unactivated user.

**Request Payload:**
```json
{
    "email": "alice@example.com"
}
```

### 3. Request Password Reset Email
**`POST /v1/tokens/password-reset`**

**Request Payload:**
```json
{
    "email": "alice@example.com"
}
```
