// Package auth verifies Cognito JSON Web Tokens against the user pool's JWKS.
package auth

import (
	"context"
	"errors"
	"fmt"
	"slices"
	"strings"

	"github.com/coreos/go-oidc/v3/oidc"
)

// Claims holds the parts of a verified token the services use.
type Claims struct {
	Subject string
	Email   string
}

type rawClaims struct {
	TokenUse string `json:"token_use"`
	ClientID string `json:"client_id"`
	Email    string `json:"email"`
	Username string `json:"username"`
}

// Verifier checks tokens issued by one Cognito user pool for one app client.
type Verifier struct {
	clientID string
	oidc     *oidc.IDTokenVerifier
}

// NewVerifier builds a verifier over the issuer's JWKS. Keys are fetched on
// first use and refreshed when a token carries an unknown key id.
func NewVerifier(ctx context.Context, issuer, clientID string) *Verifier {
	issuer = strings.TrimSuffix(issuer, "/")
	keys := oidc.NewRemoteKeySet(ctx, issuer+"/.well-known/jwks.json")
	return &Verifier{
		clientID: clientID,
		// Audience differs between id and access tokens, so Verify checks it.
		oidc: oidc.NewVerifier(issuer, keys, &oidc.Config{SkipClientIDCheck: true}),
	}
}

// Verify checks the signature, the issuer, the expiry, and the app client, and
// returns the claims the services use.
func (v *Verifier) Verify(ctx context.Context, rawToken string) (*Claims, error) {
	if rawToken == "" {
		return nil, errors.New("auth: empty token")
	}
	token, err := v.oidc.Verify(ctx, rawToken)
	if err != nil {
		return nil, fmt.Errorf("auth: verifying token: %w", err)
	}

	var c rawClaims
	if err := token.Claims(&c); err != nil {
		return nil, fmt.Errorf("auth: reading claims: %w", err)
	}

	switch c.TokenUse {
	case "id":
		if !slices.Contains(token.Audience, v.clientID) {
			return nil, errors.New("auth: id token is for another app client")
		}
		return &Claims{Subject: token.Subject, Email: c.Email}, nil
	case "access":
		if c.ClientID != v.clientID {
			return nil, errors.New("auth: access token is for another app client")
		}
		// A pool with email as the username attribute puts a UUID in username,
		// so an email claim, when the pool adds one, is the better name.
		name := c.Email
		if name == "" {
			name = c.Username
		}
		return &Claims{Subject: token.Subject, Email: name}, nil
	default:
		return nil, fmt.Errorf("auth: unsupported token_use %q", c.TokenUse)
	}
}
