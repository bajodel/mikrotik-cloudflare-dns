## ---- Configuration/Start  -----

# Cloudflare parameters (see README.md https://github.com/bajodel/mikrotik-cloudflare-dns )
#(optional)# :local CfApiAuthEmail "mymail@mydomain.com"
:local CfApiDnsRcName "mywanip.domain.com"
:local CfApiDnsZoneID "__Cloudflare_Dns_Zone_ID____"
:local CfApiDnsRcrdID "__Cloudflare_Dns_Record_ID__"
:local CfApiAuthToken "__Cloudflare_Auth_Key_Token_"
  
# if [false] it will only monitor/log WanIP changes, if [true] it will enable Cloudflare DNS update
:local CfApiUpdEnable true;

# install DigiCert-Root-CA on your board if you want to enable "check-certificate"
:local CfApiCertCheck false;

## ---- Configuration/End  ----

:global WanIP4Cur
:do {
:local result [:tool fetch url="http://checkip.amazonaws.com/" as-value output=user]
:if ($result->"status" = "finished") do={
  :local WanIP4New [:pick ($result->"data") 0 ( [ :len ($result->"data") ] -1 )]
  :if ($WanIP4New != $WanIP4Cur) do={
    :if ([ :len ($WanIP4New) ] > 4) do={
      # wan ip changed (result not empty and != stored ip)
      :log warning "[script] IP wan change detected - New IP: $WanIP4New - Old IP: $WanIP4Cur";
      # If not in "Monitor Only" state -> update Cloudflare DNS
      :if ($CfApiUpdEnable = true) do={
      # create API update url for DNS Zone/Record
      :local url "https://api.cloudflare.com/client/v4/zones/$CfApiDnsZoneID/dns_records/$CfApiDnsRcrdID/"
      # evaluating "check-certificate" (yes/no)
      :local CheckYesNo
      :if ($CfApiCertCheck = true) do={ :set CheckYesNo "yes"; } else={ :set CheckYesNo "no"; }
      # evaluating if optional parameter "CfApiAuthEmail" is populated or empty
      :if ($CfApiAuthEmail = "") do={
        # updating the DNS Record
        :local cfapi [/tool fetch http-method=put mode=https url=$url check-certificate=$CheckYesNo output=user as-value \
        http-header-field="Authorization: Bearer $CfApiAuthToken,Content-Type: application/json" \
        http-data="{\"type\":\"A\",\"name\":\"$CfApiDnsRcName\",\"content\":\"$WanIP4New\",\"ttl\":60,\"proxied\":false}"]
      } else={
        # updating the DNS Record
        :local cfapi [/tool fetch http-method=put mode=https url=$url check-certificate=$CheckYesNo output=user as-value \
        http-header-field="X-Auth-Email: $CfApiAuthEmail,Authorization: Bearer $CfApiAuthToken,Content-Type: application/json" \
        http-data="{\"type\":\"A\",\"name\":\"$CfApiDnsRcName\",\"content\":\"$WanIP4New\",\"ttl\":60,\"proxied\":false}"]
      }
      # log message
      :log warning "[script] Updated Cloudflare DNS record [ $CfApiDnsRcName -> $WanIP4New ]";
      }
      # update stored global variable
      :set WanIP4Cur $WanIP4New
    }
  }
}
} on-error={
  :log error "[script] Error retrieving current WanIP or updating Cloudflare DNS record";
}
