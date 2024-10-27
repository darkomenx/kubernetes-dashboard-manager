#! /bin/bash

clear

echo '----------------------------------------------------------------------------------------------------'
echo '-------------------------------------- K8s dashboard manager ---------------------------------------'
echo '----------------------------------------------------------------------------------------------------'

echo ''

echo 'This script is created for managing (install, uninstall, run and test) official Kubernetes Dashboard WebApp'
echo 'Based on official Kubernetes Dashboard repository and installed with Helm (access by SSL and localhost)'
echo 'more info : https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/'

echo ''
echo ''

echo '-----------------------------------------------------------------------'
echo '-------------------------- Requirements -------------------------------'
echo ''
echo 'kubectl : https://kubernetes.io/fr/docs/tasks/tools/install-kubectl/'
echo 'helm : https://helm.sh/docs/intro/install/'
echo ''
echo '-----------------------------------------------------------------------'
echo '-----------------------------------------------------------------------'

# init script ---------------------------------------------------------------------------------------------

pod1="kubernetes-dashboard-api"
pod2="kubernetes-dashboard-auth"
pod3="kubernetes-dashboard-kong"
pod4="kubernetes-dashboard-metrics-scraper"
pod5="kubernetes-dashboard-web"
namespace="kubernetes-dashboard"

# Function for check Pod exist
function check_pod
{
  local pod_name="$1"
  local namespace="$2"

  if ! kubectl get pods -n "$namespace" "$pod_name" > /dev/null 2>&1; then
    echo 1
  else
    echo 0
  fi
}

# Function for display error & quit
function error_exit
{
  echo "Error : Invalid Option. Please choose 1, 2, 3 or 4"
  exit 1
}

echo ''



#requirements test -----------------------------------------------------------------------------------------

binary_kubectl="kubectl"
binary_helm="helm"

command -v "kubectl" > NUL 2>&1

if [ $? -ne 0 ]; then
  echo "The binary 'binary_kubectl' is not present in your PATH system."
  echo "please install Kubectl (more info : https://kubernetes.io/fr/docs/tasks/tools/install-kubectl/)"
  exit 1
fi

command -v "helm" > NUL 2>&1

if [ $? -ne 0 ]; then
  echo "The binary 'binary_helm' is not present in your PATH system."
  echo "please install Helm (more info : https://helm.sh/docs/intro/install/)"
  exit 1
fi


# script mode asking ---------------------------------------------------------------------------------------

echo "Choose your action :
1. Uninstall
2. Install & Run
3. Run
4. Test"
read mode


case $mode in

  1)
    echo ''
    echo "Uninstall action..."
    echo ''

    echo "Uninstall kubernetes-dashboard"
    helm uninstall kubernetes-dashboard -n kubernetes-dashboard > NUL 2>&1
    sleep 2&
    wait

    echo "Uninstall kubernetes-dashboard namespace"
    kubectl delete namespace kubernetes-dashboard  > NUL 2>&1
    sleep 2&
    wait

    echo "Uninstall service-account-admin-user"
    kubectl delete serviceaccount admin-user -n kubernetes-dashboard > NUL 2>&1
    sleep 3&
    wait

    echo "Uninstall cluster-role-binding-admin-user"
    kubectl delete clusterrolebinding admin-user -n kubernetes-dashboard > NUL 2>&1
    sleep 3&
    wait

    echo ''
    echo 'all resources from Kubernetes Dashboard are uninstalled !'

    ;;

  2)
    echo ''
    echo "Install action..."
    echo ''

    # check repository ------------------------------------------------------------------------------------------

    echo '----- repository'

    if helm repo list | grep 'https://kubernetes.github.io/dashboard/'; then

        echo "The repository is already installed"

    else

        echo "the repository is not installed !"
        echo "starting install..."

        helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
        sleep 5&
        wait

        echo "install done !"
    fi

    echo ''
    echo '----- install deployment'

    result1=$(check_pod "$pod1" "$namespace")
    result2=$(check_pod "$pod2" "$namespace")
    result3=$(check_pod "$pod3" "$namespace")
    result4=$(check_pod "$pod4" "$namespace")
    result5=$(check_pod "$pod5" "$namespace")

    # Check dashboard chart helm ------------------------------------------------------------------------------------------

    if [[ "$result1" == 1 || "$result2" == 1 || "$result3" == 1 || "$result4" == 1 || "$result5" == 1 ]]; then

      echo "Some Pods are not present in the Cluster"
      echo "reinstallation du dashboard...."

      helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --create-namespace --namespace kubernetes-dashboard
      sleep 15&
      wait

    else

      echo "The dashboard is already installed"
    fi

    # Check Service Account exist -------------------------------------------------------------------------------

    echo ''
    echo '----- install Service Account'

    if kubectl get serviceaccount admin-user -n kubernetes-dashboard | grep 'admin-user'; then

      echo "ServiceAccount admin-user already installed"

    else

      echo "ServiceAccount admin-user not installed"
      echo "installation of ServiceAccount admin-user..."

      kubectl apply -f ./dashboard-adminuser-serviceAccount.yml
      sleep 5&
      wait
    fi

    # Check ClusterRoleBinding exist -----------------------------------------------------------------------------

    echo ''
    echo '----- install Cluster Role Binding'

    if kubectl get clusterrolebinding admin-user -n kubernetes-dashboard | grep 'admin-user'; then

      echo "ClusterRoleBinding admin-user already installed"

    else

      echo "ClusterRoleBinding admin-user not installed"
      echo "installation of ClusterRoleBinding admin-user..."

      kubectl apply -f ./dashboard-adminuser-clusterrolebinding.yml
      sleep 5&
      wait
    fi

    # Get Bearer Token -------------------------------------------------------------------------------------------

    echo ''
    echo 'create the Bearer Token access (Copy -> Paste)'
    kubectl -n kubernetes-dashboard create token admin-user

    # install port-Forwarding

    echo ''
    echo '----- port-Forwarding'

    echo ''
    echo 'Now you can run webapp on : https://localhost:8443'
    echo 'use the previous bearer token access generate into login form'
    echo ''

    kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443

    sleep 999999999999999999999999999999999999&
    wait

    ;;

  3)

    echo "Is kubernetes-dashboard Helm repository installed ?"

    if helm repo list | grep -q 'https://kubernetes.github.io/dashboard/'; then

      echo "The repository is OK !"
      hasRepo=1

    else

      echo "the repository is not installed !"
      hasRepo=0
    fi

    echo ''

    echo "Is kubernetes-dashboard helm chart installed ?"

    if helm list --all-namespaces | grep -q 'kubernetes-dashboard'; then

      echo "The release kubernetes-dashboard is OK !"
      hasChart=1

    else

      echo "The release kubernetes-dashboard is not installed !"
      hasChart=0
    fi

    echo ''

    echo "Is serviceAccount deployment installed ?"

    if kubectl get serviceaccount -n kubernetes-dashboard | grep -q 'admin-user'; then

      echo "ServiceAccount admin-user is OK !"
      hasServiceAccount=1

    else

      echo "ServiceAccount admin-user not installed"
      hasServiceAccount=0
    fi

    echo ''

    echo "Is clusterRoleBinding deployment installed ?"

    if kubectl get clusterrolebinding -n kubernetes-dashboard | grep -q 'admin-user'; then

      echo "ClusterRoleBinding admin-user is OK !"
      hasClusterRoleBinding=1

    else

      echo "ClusterRoleBinding admin-user not installed"
      hasClusterRoleBinding=0
    fi

    echo ''


    if [[ "$hasRepo" == 1 || "$hasChart" == 1 || "$hasServiceAccount" == 1 || "$hasClusterRoleBinding" == 1 ]]; then

      echo ""
      echo "-------------------------------------------------------------------"
      echo "All resources requirements are OK !"
      echo "-------------------------------------------------------------------"
      echo ""

    else

      echo 'You need to install : '

      if [[ "$hasRepo" == 0 ]]; then
        echo "the helm repository kubernetes dashboard"
      fi

      if [[ "$hasChart" == 0 ]]; then
        echo "the chart deployment kubernetes dashboard"
      fi

      if [[ "$hasServiceAccount" == 0 ]]; then
        echo "the service Account"
      fi

      if [[ "$hasClusterRoleBinding" == 0 ]]; then
        echo "the cluster Role Binding"
      fi

    fi

    # Get Bearer Token -------------------------------------------------------------------------------------------

    echo ''
    echo 'create the Bearer Token access (Copy -> Paste)'
    kubectl -n kubernetes-dashboard create token admin-user

    # install port-Forwarding

    echo ''
    echo '----- port-Forwarding'

    echo ''
    echo 'Now you can run webapp on : https://localhost:8443'
    echo 'use the previous bearer token access generate into login form'
    echo ''

    kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443

    sleep 999999999999999999999999999999999999&
    wait

    ;;

  4)
    echo ''
    echo "Test action..."
    echo ''

    echo "Is kubernetes-dashboard Helm repository installed ?"

    if helm repo list | grep -q 'https://kubernetes.github.io/dashboard/'; then

      echo "The repository is already installed"
      hasRepo=1

    else

      echo "the repository is not installed !"
      hasRepo=0
    fi

    echo ''

    echo "Is kubernetes-dashboard helm chart installed ?"

    if helm list --all-namespaces | grep -q 'kubernetes-dashboard'; then

      echo "The release kubernetes-dashboard is already installed"
      hasChart=1

    else

      echo "The release kubernetes-dashboard is not installed !"
      hasChart=0
    fi

    echo ''

    echo "Is serviceAccount deployment installed ?"

    if kubectl get serviceaccount -n kubernetes-dashboard | grep -q 'admin-user'; then

      echo "ServiceAccount admin-user already installed"
      hasServiceAccount=1

    else

      echo "ServiceAccount admin-user not installed"
      hasServiceAccount=0
    fi

    echo ''

    echo "Is clusterRoleBinding deployment installed ?"

    if kubectl get clusterrolebinding -n kubernetes-dashboard | grep -q 'admin-user'; then

      echo "ClusterRoleBinding admin-user already installed"
      hasClusterRoleBinding=1

    else

      echo "ClusterRoleBinding admin-user not installed"
      hasClusterRoleBinding=0
    fi

    echo ''


    if [[ "$hasRepo" == 1 || "$hasChart" == 1 || "$hasServiceAccount" == 1 || "$hasClusterRoleBinding" == 1 ]]; then

      echo ""
      echo "-------------------------------------------------------------------"
      echo ""
      echo "All resources requirements is installed"
      echo ""
      echo "You can launch the '3. Run' choice on this script for running the proxy "
      echo "and access from your browser at : https://localhost:8443"

    else

      echo 'You need to install : '

      if [[ "$hasRepo" == 0 ]]; then
        echo "the helm repository kubernetes dashboard"
      fi

      if [[ "$hasChart" == 0 ]]; then
        echo "the chart deployment kubernetes dashboard"
      fi

      if [[ "$hasServiceAccount" == 0 ]]; then
        echo "the service Account"
      fi

      if [[ "$hasClusterRoleBinding" == 0 ]]; then
        echo "the cluster Role Binding"
      fi

    fi

    ;;

  *)
    error_exit
    ;;
esac

# Finish script ------------------------------------------------

echo ''
exit;
