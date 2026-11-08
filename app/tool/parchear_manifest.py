"""Agrega al AndroidManifest el permiso de Internet, el bloque <queries> que necesita
url_launcher en Android 11+ y el nombre visible de la app. Es idempotente."""
import re
import sys

ruta = sys.argv[1]
xml = open(ruta, encoding="utf-8").read()

if "android.permission.INTERNET" not in xml:
    xml = xml.replace(
        "<application",
        '<uses-permission android:name="android.permission.INTERNET"/>\n    <application',
        1,
    )

INTENTS = """        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="https" />
        </intent>
        <intent>
            <action android:name="android.intent.action.SEND" />
            <data android:mimeType="text/plain" />
        </intent>
"""

if "android.intent.action.VIEW" not in xml:
    if "<queries>" in xml:  # las plantillas nuevas de Flutter ya traen un bloque <queries>
        xml = xml.replace("<queries>", "<queries>\n" + INTENTS.rstrip("\n"), 1)
    else:
        xml = re.sub(r"</manifest>\s*$", "    <queries>\n" + INTENTS + "    </queries>\n</manifest>\n", xml)

xml = re.sub(r'android:label="[^"]*"', 'android:label="Oportunidades"', xml, count=1)

open(ruta, "w", encoding="utf-8").write(xml)
print("Manifest parcheado")
