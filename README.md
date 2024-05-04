# Mikrotik Cloudflare DNS Updater Script (RouterOS v7)

Script for [Mikrotik](https://mikrotik.com/) RouterOS v7 routers that updates a Cloudflare DNS record when the router's public IP address has changed.

Note: Mikrotik RouterOS already includes a [IP Cloud DDNS](https://wiki.mikrotik.com/wiki/Manual:IP/Cloud#DDNS) feature
that works great and can be used to recursively update (using `CNAME`) records that point to the Mikrotik generated
dynamic DNS record (for example `529c0491d41c.sn.mynetname.net`).

I needed a script to log Wan-IP changes and, optionally, could also do the Cloudflare DNS update.
This script is the result.

## Setup

* `CFAPIAUTHEMAIL` - the email associated to your Cloudflare account (needed for API Auth).
* `CFAPIDNSRCNAME` - the domain record (hostname) at Cloudflare that you want to update. For example `mywanip.domain.com`.
* `CFAPIDNSZONEID` - Cloudflare Dns Zone ID, you can find it in the Cloudflare dashboard.
* `CFAPIDNSRCRDID` - Cloudflare Dns Record ID. See below.
* `CFAPIAUTHTOKEN` - the Cloudflare AuthKey/Token, you can find it in the Cloudflare dashboard.


### API Token

The `API TOKEN` (CFAPIAUTHTOKEN) value is created in the Cloudflare dashboard.

1. Click the profile icon in the top right of the dashboard, and choose 'My Profile'.
2. Click on 'API Tokens', then 'Create Token'.
3. Click 'Start with a template', then choose the 'Edit zone DNS' template.
4. Under 'Zone Resources', choose your top level domain name.
5. Click 'Continue to summary'.
6. Click 'Create Token'.
