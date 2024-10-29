provider "kubernetes" {
  host                   = "https://${data.minikube_ip.ip}:8443"
  token                  = data.minikube_k8s_token.token
  cluster_ca_certificate = base64decode(data.minikube_ca.ca_certificate)
}

data "minikube_ip" "ip" {}
data "minikube_k8s_token" "token" {}
data "minikube_ca" "ca" {}

resource "helm_release" "istio" {
  name       = "istio-base"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istio-base"
  version    = "1.18.0"  # Убедитесь, что версия актуальна

  set {
    name  = "global.hub"
    value = "docker.io/istio"
  }
  set {
    name  = "global.tag"
    value = "1.18.0"
  }
}

resource "helm_release" "istiod" {
  name       = "istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"
  version    = "1.18.0"

  set {
    name  = "global.hub"
    value = "docker.io/istio"
  }
  set {
    name  = "global.tag"
    value = "1.18.0"
  }
}

resource "helm_release" "istio_ingress" {
  name       = "istio-ingress"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istio-ingress"
  version    = "1.18.0"

  set {
    name  = "global.hub"
    value = "docker.io/istio"
  }
  set {
    name  = "global.tag"
    value = "1.18.0"
  }
}

resource "kubernetes_deployment" "httpd" {
  metadata {
    name      = "httpd"
    namespace = "default"
    labels = {
      app = "httpd"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "httpd"
      }
    }
    template {
      metadata {
        labels = {
          app = "httpd"
        }
      }
      spec {
        container {
          name  = "httpd"
          image = "httpd:2.4"
          ports {
            container_port = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "httpd" {
  metadata {
    name      = "httpd"
    namespace = "default"
    labels = {
      app = "httpd"
    }
  }
  spec {
    selector = {
      app = "httpd"
    }
    port {
      port        = 80
      target_port = 80
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_virtual_service" "httpd" {
  metadata {
    name      = "httpd"
    namespace = "default"
  }
  spec {
    hosts = ["httpd.example.com"]
    gateways = ["istio-ingressgateway"]
    http {
      route {
        destination {
          host = kubernetes_service.httpd.metadata[0].name
          port {
            number = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_gateway" "httpd" {
  metadata {
    name      = "httpd-gateway"
    namespace = "default"
  }
  spec {
    selector = {
      istio = "ingressgateway"
    }
    gateway_class_name = "istio"
    port {
      name     = "http"
      port     = 80
      protocol = "HTTP"
    }
  }
}
