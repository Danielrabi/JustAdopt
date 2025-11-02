terraform {
  source = "../../../modules/storage"
}

inputs = {
  env = "dev"
  bucket_name_prefix = "justadopt"
}