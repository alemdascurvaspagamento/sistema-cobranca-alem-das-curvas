"""Mostra a situação do TestFlight do app e prepara o teste interno.

- lista as versões enviadas e se já foram processadas;
- garante um grupo de teste interno "Equipe" com acesso a todas as versões;
- coloca nele os usuários da conta (App Store Connect) que ainda não estão.
"""
import os, sys, time, json, urllib.request, urllib.error, urllib.parse
import jwt

API = "https://api.appstoreconnect.apple.com/v1"
BUNDLE_ID = os.environ.get("BUNDLE_ID", "br.com.alemdascurvas.coachflow")

def token():
    now = int(time.time())
    return jwt.encode({"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 1000, "aud": "appstoreconnect-v1"},
                      os.environ["ASC_PRIVATE_KEY"], algorithm="ES256", headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"})

def call(method, path, body=None):
    req = urllib.request.Request(API + path, method=method, data=None if body is None else json.dumps(body).encode(),
                                 headers={"Authorization": f"Bearer {token()}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as r:
            raw = r.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        msg = e.read().decode(errors="replace")[:700]
        print(f"::warning title=API {e.code}::{method} {path} -> {msg}")
        return None

def note(title, msg):
    print(f"::notice title={title}::{msg}")

app = call("GET", "/apps?" + urllib.parse.urlencode({"filter[bundleId]": BUNDLE_ID}))["data"][0]
aid = app["id"]

builds = call("GET", "/builds?" + urllib.parse.urlencode({"filter[app]": aid, "sort": "-uploadedDate", "limit": 10,
               "fields[builds]": "version,processingState,uploadedDate,expired"}))["data"]
lines = [f"versão {b['attributes']['version']}: {b['attributes']['processingState']}" for b in builds]
note("Versões no TestFlight", " | ".join(lines) or "nenhuma")

groups = call("GET", f"/apps/{aid}/betaGroups")["data"]
internal = [g for g in groups if g["attributes"].get("isInternalGroup")]
if internal:
    group = internal[0]
    note("Grupo interno", f"{group['attributes']['name']} já existe")
else:
    r = call("POST", "/betaGroups", {"data": {"type": "betaGroups",
             "attributes": {"name": "Equipe", "isInternalGroup": True, "hasAccessToAllBuilds": True},
             "relationships": {"app": {"data": {"type": "apps", "id": aid}}}}})
    if not r:
        sys.exit(0)
    group = r["data"]
    note("Grupo interno", "Equipe criado, com acesso a todas as versões")

gid = group["id"]
current = call("GET", f"/betaGroups/{gid}/betaTesters?limit=200")["data"]
emails = {t["attributes"].get("email", "").lower() for t in current}
note("Testadores no grupo", ", ".join(sorted(emails)) or "nenhum")

users = call("GET", "/users?limit=50")
for u in (users or {}).get("data", []):
    email = u["attributes"]["username"].lower()
    if email in emails:
        continue
    r = call("POST", "/betaTesters", {"data": {"type": "betaTesters",
             "attributes": {"email": email, "firstName": u["attributes"].get("firstName", ""), "lastName": u["attributes"].get("lastName", "")},
             "relationships": {"betaGroups": {"data": [{"type": "betaGroups", "id": gid}]}}}})
    if r:
        note("Convite enviado", email)
