terraform {
  source = "../../../modules/storage"
}

inputs = {
  env = "prod"
  bucket_name_prefix = "justadopt"
}