# Aufsatz auf das veröffentlichte Abbild vom 2025-12-11 (fester Digest).
#
# Warum kein Bau von Grund auf: Die Basis php:7.4-apache steht auf Debian 11. Dessen
# Paketquellen sind seit 2026 abgekündigt und liefern 404; `Dockerfile.grundbau` baut
# deshalb nicht mehr (Stand 2026-10-11). Bis der Grundbau repariert oder die Basis
# erneuert ist, legt dieses Dockerfile nur Änderungen über das laufende Abbild.
# So ändert sich beim Kunden außer diesen Zeilen kein Byte.
FROM ghcr.io/deltatree/contao@sha256:59ad8ba8d41700bdb8ea5b8a53f97baf751508d5409b04fd91defb2bca54b838

# Apache prefork begrenzen: höchstens so viele Prozesse, wie in die Speichergrenze passen
ENV APACHE_MAX_REQUEST_WORKERS=20 \
    APACHE_MAX_CONNECTIONS_PER_CHILD=500
COPY docker/apache/mpm_prefork.conf /etc/apache2/mods-available/mpm_prefork.conf
