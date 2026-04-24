"""Generate Prisma client from LiteLLM's bundled schema at build time."""
import glob
import subprocess
import sys

search_paths = [
    "/app/.venv/lib/python*/site-packages/litellm/proxy/**/schema.prisma",
    "/usr/local/lib/python*/site-packages/litellm/proxy/**/schema.prisma",
]

matches = []
for pattern in search_paths:
    matches = glob.glob(pattern, recursive=True)
    if matches:
        break

if not matches:
    print("ERROR: No Prisma schema found in any search path")
    sys.exit(1)

schema_path = matches[0]
print(f"Found schema at: {schema_path}")
subprocess.run(["prisma", "generate", f"--schema={schema_path}"], check=True)
print("Prisma client generated successfully")
