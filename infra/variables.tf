variable "YC_KEYS" {
  type = object({
    folder_id          = string
    service_account_id = string
  })
  description = "ID облака YC и сервисного аккаунта"
}

variable "image_id" {
  type        = string
  description = "ID общедоступного дистрибутива"
}

variable "adminwks_image_id" {
  type        = string
  description = "ID дистрибутива управляющего компьютера (YC IPSec-инстанс)"
}

variable "site_name" {
  type        = string
  description = "DNS-имя сайта"
}

variable "nlb_name" {
  type        = string
  description = "имя балансировщика нагрузки"
}
