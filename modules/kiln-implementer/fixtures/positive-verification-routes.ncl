let make_profile = import "campaign-profile-case.ncl" in
make_profile {
  aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa = {
    ci_service_profile = "/etc/ci/service.json",
    verification_profile = "/etc/ci/verification.json",
  },
}
