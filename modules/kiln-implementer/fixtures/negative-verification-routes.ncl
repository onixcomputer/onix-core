let make_profile = import "campaign-profile-case.ncl" in
make_profile {
  aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa = {
    ci_service_profile = 17,
    verification_profile = "/etc/ci/verification.json",
  },
}
