package main

# 事故来源:litestream v0.5 默认 15s 一次 L0 retention 检查,每次都对 S3 发 LIST(Class A)
# 判据:对成本/可用性有影响的默认值,必须显式设置,对上游默认值漂移免疫

deny contains msg if {
	not input["l0-retention-check-interval"]
	msg := "l0-retention-check-interval 未显式设置:v0.5 默认 15s,每次检查都对 S3 发 LIST(Class A),需显式拉长(如 1h)"
}

deny contains msg if {
	not input["sync-interval"]
	msg := "sync-interval 未显式设置:默认 1s 会让 WAL 上传 PUT(Class A) 过于频繁,需显式拉长(如 10m)"
}

warn contains msg if {
	endswith(input["sync-interval"], "s")
	msg := sprintf("sync-interval=%s 为秒级粒度,Class A PUT 会过于频繁,建议 >= 5m", [input["sync-interval"]])
}
