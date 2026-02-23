import json
import sys
import base64
from datetime import datetime, timedelta, timezone
from cryptography import x509
import os

DEBUG = os.environ.get("DEBUG", False)


def cleanup_certs(acme_file="acme.json"):
    """
    Deletes all expired certificates from acme.json.
    """
    try:
        with open(acme_file, "r") as f:
            data = json.load(f)
    except FileNotFoundError:
        print(f"Error: {acme_file} not found.")
        return

    now = datetime.now()
    if DEBUG:
        print(f"DEBUG: current time: {now}")

    cleaned_count = 0

    def process_certificates(certificates, version):
        nonlocal cleaned_count
        if not certificates:
            return [], 0

        original_cert_count = len(certificates)
        certs_to_keep = []
        removed_certs = []
        for cert in certificates:
            cert_b64 = ""
            domain = "N/A"
            try:
                if version == 1:
                    cert_b64 = cert.get("Certificate", "")
                    domain = cert.get("Domain", {}).get("Main", "N/A")
                elif version in [2, 3]:
                    cert_b64 = cert.get("certificate", "")
                    domain = cert.get("domain", {}).get("main", "N/A")

                if cert_b64:
                    cert_b64_decoded = cert_b64.replace("-", "+").replace("_", "/")
                    padding_needed = len(cert_b64_decoded) % 4
                    if padding_needed != 0:
                        cert_b64_decoded += "=" * (4 - padding_needed)

                    cert_pem_bytes = base64.b64decode(cert_b64_decoded)
                    x509_cert = x509.load_pem_x509_certificate(cert_pem_bytes)
                    not_after_date = x509_cert.not_valid_after_utc

                    if DEBUG:
                        print(
                            f"DEBUG: Processing domain {domain}, not_valid_after: {not_after_date}"
                        )

                    if not_after_date > datetime.now(timezone.utc):
                        certs_to_keep.append(cert)
                    else:
                        removed_certs.append(domain)
                else:
                    certs_to_keep.append(cert)
            except Exception as e:
                print(f"Could not process certificate for domain {domain}: {e}")
                certs_to_keep.append(cert)

        removed_count = original_cert_count - len(certs_to_keep)

        # We only want to add to the cleaned_count if we are in a v2/v3 file,
        # because the v1 file has only one list of certs and we will get the
        # count from the return value of this function.
        if version in [2, 3]:
            cleaned_count += removed_count

        for domain_name in removed_certs:
            print(f"Removed certificate for: {domain_name}")

        return certs_to_keep, removed_count

    # Detect acme.json version
    version = None
    if (
        isinstance(data, dict)
        and "Certificates" in data
        and isinstance(data.get("Certificates"), list)
    ):
        version = 1
    elif isinstance(data, dict):
        for key, value in data.items():
            if isinstance(value, dict) and "Certificates" in value:
                version = 2  # Treat as v2/v3 generic
                break

    if DEBUG:
        print(f"DEBUG: Detected version: {version}")

    if version == 1:
        certs_to_keep, removed_count = process_certificates(
            data["Certificates"], version
        )
        if removed_count > 0:
            data["Certificates"] = certs_to_keep
            cleaned_count = removed_count
    elif version == 2:
        for resolver, resolver_data in data.items():
            if (
                isinstance(resolver_data, dict)
                and "Certificates" in resolver_data
                and resolver_data["Certificates"] is not None
            ):
                if DEBUG:
                    print(f"DEBUG: Processing resolver: '{resolver}'")
                certs_to_keep, _ = process_certificates(
                    resolver_data["Certificates"], version
                )
                resolver_data["Certificates"] = certs_to_keep
            else:
                if DEBUG:
                    print(f"DEBUG: Resolver '{resolver}': No certificates to process.")

    else:
        print("Could not determine the structure of the acme.json file.")
        return

    if cleaned_count == 0:
        print("No expired certificates to remove.")
    else:
        try:
            with open(acme_file, "w") as f:
                json.dump(data, f, indent=4)
            print(
                f"Successfully cleaned up {cleaned_count} certificates in {acme_file}."
            )
        except Exception as e:
            print(f"Error writing to {acme_file}: {e}")


if __name__ == "__main__":
    help_message = """
Usage: python3 cleanup_certs.py [--help] [acme_file]

Deletes all expired certificates from an acme.json file.
The script attempts to auto-detect the acme.json file version (v1 or v2/v3).

Arguments:
  acme_file   Optional. Path to the acme.json file. Defaults to "acme.json".
  --help      Display this help message and exit.
"""

    if "--help" in sys.argv:
        print(help_message)
        sys.exit(0)

    if len(sys.argv) > 1 and sys.argv[1] != "--help":
        file_path = sys.argv[1]
    else:
        file_path = "acme.json"

    cleanup_certs(file_path)
