package main

valid := {
	"sync-interval": "10m",
	"l0-retention-check-interval": "1h",
}

test_valid_config_has_no_deny if {
	count(deny) == 0 with input as valid
}

test_missing_l0_retention_check_interval_denied if {
	count(deny) > 0 with input as {"sync-interval": "10m"}
}

test_missing_sync_interval_denied if {
	count(deny) > 0 with input as {"l0-retention-check-interval": "1h"}
}

test_seconds_sync_interval_warns if {
	count(warn) > 0 with input as {
		"sync-interval": "15s",
		"l0-retention-check-interval": "1h",
	}
}

test_valid_config_has_no_warn if {
	count(warn) == 0 with input as valid
}
