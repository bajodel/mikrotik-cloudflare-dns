## ---- Configuration/Start  ----------------------------------------------------------------

# Cloudflare parameters (Email, DnsHost, ZoneID, RecordID, Token/AuthKey)
:local CFAPIAUTHEMAIL "mymail@mydomain.com"
:local CFAPIDNSRCNAME "mywanip.domain.com"
:local CFAPIDNSZONEID "_____Cloudflare_Dns_Zone_ID_____"
:local CFAPIDNSRCRDID "____Cloudflare_Dns_Record_ID____"
:local CFAPIAUTHTOKEN "___Cloudflare__Auth_Key_Token___"
  
# if [CFAPIUPDENABLE false] it will only monitor/log WanIP changes (no Cloudflare update)
:local CFAPIUPDENABLE true;

# install DigiCert-Root-CA on your board if you want to enable "check-certificate"
:local CFAPICERTCHECK false;

## ---- Configuration/End  ------------------------------------------------------------------

:global WANIP4CUR
:do {
:local result [:tool fetch url="http://checkip.amazonaws.com/" as-value output=user]
:if ($result->"status" = "finished") do={
  :local WANIP4NEW [:pick ($result->"data") 0 ( [ :len ($result->"data") ] -1 )]
  :if ($WANIP4NEW != $WANIP4CUR) do={
    :if ([ :len ($WANIP4NEW) ] > 4) do={
      # wan ip changed (result not empty and != stored ip)
      :log warning "[script] IP wan change detected - New IP: $WANIP4NEW - Old IP: $WANIP4CUR";
      # If not in "Monitor Only" state -> update Cloudflare DNS
      :if ($CFAPIUPDENABLE = true) do={
      # create API update url for DNS Zone/Record
      :local url "https://api.cloudflare.com/client/v4/zones/$CFAPIDNSZONEID/dns_records/$CFAPIDNSRCRDID/"
      # evaluating "check-certificate" (yes/no)
      :local CHECKYESNO
      :if ($CFAPICERTCHECK = true) do={ :set CHECKYESNO "yes"; } else { :set CHECKYESNO "no"; }
      # updating the DNS Record
      :local cfapi [/tool fetch http-method=put mode=https url=$url check-certificate=$CHECKYESNO output=user as-value \
      http-header-field="X-Auth-Email: $CFAPIAUTHEMAIL,Authorization: Bearer $CFAPIAUTHTOKEN,Content-Type: application/json" \
      http-data="{\"type\":\"A\",\"name\":\"$CFAPIDNSRCNAME\",\"content\":\"$WANIP4NEW\",\"ttl\":60,\"proxied\":false}"]
      # log message
      :log warning "[script] Updated Cloudflare DNS record [ $CFAPIDNSRCNAME -> $WANIP4NEW ]";
      }
      # update stored global variable
      :set WANIP4CUR $WANIP4NEW
    }
  }
}
} on-error={
  :log error "[script] Error retrieving current WanIP or updating Cloudflare DNS record";
}
