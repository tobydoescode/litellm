"""Generate Prisma client from LiteLLM's bundled schema at build time."""
import glob
import subprocess

# Find the schema file within the litellm package
matches = glob.glob("/usr/local/lib/python*/site-packages/litellm/proxy/**/schema.prisma", recursive=True)

if not matches:
    print("WARNING: No Prisma schema found, skipping generation")
    exit(0)

schema_path = matches[0]
print(f"Found schema at: {schema_path}")
subprocess.run(["prisma", "generate", f"--schema={schema_path}"], check=True)
print("Prisma client generated successfully")
