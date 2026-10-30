"""Prepara a App Store Connect para o Coach Flow (roda no GitHub, nunca no app).

- garante que o identificador do app (bundle ID) existe;
- descobre o ID do time da Apple (necessário para assinar);
- confere se o app já foi criado na App Store Connect.

Lê ASC_ISSUER_ID, ASC_KEY_ID e ASC_PRIVATE_KEY do ambiente.
Escreve team_id e app_ready em $GITHUB_OUTPUT.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

import jwt  # PyJWT

APP_NAME = os.environ.get("APP_NAME", "")  # nome na App Store (opcional)

BUNDLE_ID = os.environ.get("BUNDLE_ID", "br.com.alemdascurvas.coachflow")
API = "https://api.appstoreconnect.apple.com/v1"


def token():
    now = int(time.time())
    return jwt.encode(
        {"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 1000, "aud": "appstoreconnect-v1"},
        os.environ["ASC_PRIVATE_KEY"],
        algorithm="ES256",
        headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"},
    )


def call(method, path, body=None, soft=False):
    req = urllib.request.Request(
        API + path,
        method=method,
        data=None if body is None else json.dumps(body).encode(),
        headers={"Authorization": f"Bearer {token()}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req) as r:
            return json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")
        if soft:
            print(f"::warning title=App Store Connect ({e.code})::{method} {path} -> {detail[:900]}")
            return None
        print(f"::error title=App Store Connect ({e.code})::{method} {path} -> {detail[:900]}")
        sys.exit(1)


def out(key, value):
    with open(os.environ.get("GITHUB_OUTPUT", "/dev/null"), "a") as f:
        f.write(f"{key}={value}\n")


q = urllib.parse.urlencode({"filter[identifier]": BUNDLE_ID, "limit": 200})
found = [b for b in call("GET", f"/bundleIds?{q}")["data"] if b["attributes"]["identifier"] == BUNDLE_ID]
if found:
    bundle = found[0]
    print(f"Identificador {BUNDLE_ID} já existe.")
else:
    bundle = call("POST", "/bundleIds", {
        "data": {"type": "bundleIds", "attributes": {
            "identifier": BUNDLE_ID, "name": "Coach Flow Professional", "platform": "IOS"}}
    })["data"]
    print(f"::notice title=Identificador criado::{BUNDLE_ID}")

team = bundle["attributes"]["seedId"]
out("team_id", team)
print(f"Time da Apple: {team}")

q = urllib.parse.urlencode({"filter[bundleId]": BUNDLE_ID})
apps = call("GET", f"/apps?{q}")["data"]
if apps:
    out("app_ready", "true")
    app = apps[0]
    print(f"App na App Store Connect: {app['attributes']['name']} ({app['id']})")
    if APP_NAME and app["attributes"]["name"] != APP_NAME:
        locale = app["attributes"].get("primaryLocale", "pt-BR")
        infos = call("GET", f"/apps/{app['id']}/appInfos")["data"]
        done = False
        for info in infos:
            locs = call("GET", f"/appInfos/{info['id']}/appInfoLocalizations")["data"]
            for loc in locs:
                if loc["attributes"]["locale"] != locale:
                    continue
                r = call("PATCH", f"/appInfoLocalizations/{loc['id']}", {
                    "data": {"type": "appInfoLocalizations", "id": loc["id"], "attributes": {"name": APP_NAME}}
                }, soft=True)
                if r:
                    done = True
                    print(f"::notice title=Nome na App Store::{APP_NAME}")
        if not done:
            print(f"::warning title=Nome na App Store::Não consegui trocar para {APP_NAME} (veja o aviso acima).")
else:
    out("app_ready", "false")
    print(f"::warning title=Falta criar o app::Crie o app na App Store Connect com o identificador {BUNDLE_ID}.")
