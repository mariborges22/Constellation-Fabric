import {
  to = module.kubernetes_deploy_us.kubernetes_manifest.auth_deployment
  id = "apiVersion=apps/v1,kind=Deployment,namespace=constellation,name=auth-service"
}

import {
  to = module.kubernetes_deploy_us.kubernetes_manifest.combat_deployment
  id = "apiVersion=apps/v1,kind=Deployment,namespace=constellation,name=combat-service"
}

import {
  to = module.kubernetes_deploy_us.kubernetes_manifest.nakama_deployment
  id = "apiVersion=apps/v1,kind=Deployment,namespace=constellation,name=nakama"
}

import {
  to = module.kubernetes_deploy_us.kubernetes_manifest.nakama_db_statefulset
  id = "apiVersion=apps/v1,kind=StatefulSet,namespace=constellation,name=nakama-db"
}

import {
  to = module.kubernetes_deploy_us.kubernetes_manifest.nakama_config
  id = "apiVersion=v1,kind=ConfigMap,namespace=constellation,name=nakama-config"
}
