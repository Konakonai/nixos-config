{ hostProfile, ... }:

{
  age.identityPaths = [ hostProfile.secrets.identityFile ];
}
