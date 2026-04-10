EXTERNAL_VENDOR := $(BR2_EXTERNAL)

include $(sort $(wildcard $(BR2_EXTERNAL)/package/*/*.mk))