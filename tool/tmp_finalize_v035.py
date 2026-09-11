from pathlib import Path

path = Path('.github/workflows/publish-release-assets.yml')
text = path.read_text()
if 'xueqing_backend_compatibility' in text:
    raise SystemExit('compatibility gate already present unexpectedly')

anchor = '''          if [[ -z "$XUEQING_SUPABASE_URL" || -z "$XUEQING_SUPABASE_PUBLISHABLE_KEY" || -z "$XUEQING_SUPABASE_ALLOWED_HOSTS" ]]; then
            echo "Stable production releases require Supabase URL, publishable key, and allowed hosts."
            exit 1
          fi
'''

gate = anchor + '''          backend_json="$(curl --fail-with-body --silent --show-error --retry 2 --retry-all-errors --connect-timeout 10 --max-time 30 \\
            -X POST "${XUEQING_SUPABASE_URL%/}/rest/v1/rpc/xueqing_backend_compatibility" \\
            -H "apikey: $XUEQING_SUPABASE_PUBLISHABLE_KEY" \\
            -H "Content-Type: application/json" \\
            -d '{}')"
          BACKEND_JSON="$backend_json" python3 -c 'import json, os; required_schema="20260911153000"; payload=json.loads(os.environ["BACKEND_JSON"]); actual_schema=str(payload.get("schema_version", "")); capabilities=payload.get("capabilities") or {}; missing=[name for name in ("student_profile_edit", "learning_record_export_attachments") if capabilities.get(name) is not True]; actual_schema >= required_schema or (_ for _ in ()).throw(SystemExit(f"Production backend is older than this client requires: {actual_schema!r} < {required_schema}.")); not missing or (_ for _ in ()).throw(SystemExit("Production backend is missing required capabilities: " + ", ".join(missing))); print(f"production backend schema {actual_schema} is compatible")'
'''

if text.count(anchor) != 1:
    raise SystemExit('stable publisher compatibility insertion anchor not unique')
path.write_text(text.replace(anchor, gate, 1))
