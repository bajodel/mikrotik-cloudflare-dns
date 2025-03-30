##  <<  For parameters' details see README.md @ https://github.com/bajodel/mikrotik-cloudflare-dns  >>

## ---- Configuration/Start  -----

# Define here single/multiple Dns Records (FQDNs) with their Zone IDs, Record IDs, and AuthTokens
:global ParamVect {
                  "_____mywanip1.domain.com_____"={
      "DnsZoneID"="__Cloudflare_Dns_Zone_ID1____";
      "DnsRcrdID"="__Cloudflare_Dns_Record_ID1__";
      "AuthToken"="_Cloudflare_Auth_Key_Token_1_";
  };
#                 "_____mywanip2.domain.com_____"={
#     "DnsZoneID"="__Cloudflare_Dns_Zone_ID2____";
#     "DnsRcrdID"="__Cloudflare_Dns_Record_ID2__";
#     "AuthToken"="_Cloudflare_Auth_Key_Token_2_";
# };
}

:global VerboseLog true;
:global scriptName "CloudFlare DDNS Updater";

## ---- Configuration/End  ----

:global updateCF do={
  # [default: false] enable certificate validation for Cloudflare API calls (but before install RootCA used by CF)
  :local CertCheck false;

  :foreach fqdn,params in=$ParamVect do={
    :local DnsRcName $fqdn;
    :local DnsZoneID ($params->"DnsZoneID");
    :local DnsRcrdID ($params->"DnsRcrdID");
    :local AuthToken ($params->"AuthToken");
    :if ($VerboseLog = true) do={ log info "[$scriptName] Preparing CF-DNS IPV4 Update for <$DnsRcName>" };

    :local url "https://api.cloudflare.com/client/v4/zones/$DnsZoneID/dns_records/$DnsRcrdID/";
    :if ($VerboseLog = true) do={ :log info "[$scriptName] Generated URL for DNS update: $url" };
    :if ($VerboseLog = true) do={ :log info "[$scriptName] Certificate check is globally set to $CertCheck" };

    :local CheckYesNo;
    :if ($CertCheck = true) do={ :set CheckYesNo "yes" } else={ :set CheckYesNo "no"};
 
    :local CfApiResult [/tool fetch http-method=put mode=https url=$url check-certificate=$CheckYesNo output=user as-value \
    http-header-field="Authorization: Bearer $AuthToken,Content-Type: application/json" \
    http-data="{\"type\":\"A\",\"name\":\"$DnsRcName\",\"content\":\"$WanIP4\",\"ttl\":60,\"proxied\":false}"];

    :if ($CfApiResult->"status" = "finished") do={
      :log warning "[$scriptName] Updated Cloudflare DNS A record for <$DnsRcName> to $WanIP4";
      } else={
        :log error "[$scriptName] Error occurred updating Cloudflare DNS record for <$DnsRcName> to $WanIP4";
      }
    };
    :delay 1;
}

:if ($bound=1) do={
    :local WanIP4New $"lease-address";
    :delay 2000ms;
    :log info "[$scriptName] IPV4 lease received $WanIP4New";
    $updateCF WanIP4=$WanIP4New
} else={
    :log info "[$scriptName] No IP lease, nothing to be done with DDNS or CloudFlare";
};
