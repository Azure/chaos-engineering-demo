# Troubleshooting
In case of having Issues first have a look here and try to resolve based on the proposed methods and solutions.
If all fails - please raise an Issue according to the Issue Guidelines.

## 502 Error on /v1/products/?type=laptops
When Requesting the Products the Request returns a 502 Error message and "Service is not available".

### Step 1: Make sure your AKS Cluster is Running
```shell
az aks get-credentials --resource-group YOUR_RESOURCE_GROUP --name AKS_CLUSTER_NAME --overwrite-existing
```
### Step 2: See if the Pod is Running and Check Logs
```shell
kubectl get pod
```
Some ```contoso-traders-products-XXXX``` needs to be shown as ```Running```.
```shell
kubectl logs POD_NAME
```
There should be no Errors there. Otherwise go to Pod Errors.
### Step 3: Check if you can access the AKS LoadBalancer
```shell
$lbHost = kubectl get ingress contoso-traders-products -o jsonpath="{.items[*].spec.rules[*].host}";
$lbAddress = kubectl get ingress contoso-traders-products -o jsonpath="{.items[*].status.loadBalancer.ingress[*].ip}";
```
Add the $lbAddress to your NEtwork Security Group inbound Rules of your ASK NSG so you can access the LoadBalancer directly using the DNS Name from $lbHost + /v1/products/?type=laptops.
Try calling and see if you get a 200 Response.
```shell
curl -v "${lbHost}/v1/products/?type=laptops"
```
If it works that means your NSG Rules are likely the problem.
Don't forget to remove the AKS LB NSG Rule afterwards.
### Step 4: Check if cert-manager worked properly and the certificate was issued
```shell
kubectl get certificate tls-secret             

NAME         READY   SECRET       AGE                    
tls-secret   True    tls-secret   **m
```
Check for logs on the cert-manager
```shell
kubectl get po -n cert-manager
kubectl logs cert-manager-POD-NAME -n cert-manager
```
### Step 5: Error with the certificate tls-secret
Delete the certificate
```shell
kubectl delete certificate tls-secret
```
Apply the Certificate K8S Manifest in ```\src\app\ContosoTraders.Api.Products\Manifests\Certificate.yaml```
Replace AKS_FQDN with the value from $lbHost from Step 3.
```shell
kubectl apply -f Certificate.yaml
```

## Pod Errors
### Keyvault Access
The Pod is using Entra Workload Identity to authenticate to KeyVault.
Make sure it has the role "Key Vault Secrets User" assigned:
```shell
$USER_ASSIGNED_OBJ_ID=$(az identity show --resource-group $RG_NAME --name $MANAGED_IDENTITY_NAME --query 'principalId' -o tsv)
az role assignment create --assignee-object-id $USER_ASSIGNED_OBJ_ID --role "Key Vault Secrets User" --scope $KEYVAULT_ID --assignee-principal-type ServicePrincipal
```  
Also the KeyVault Access Policy needs to include the Workload Identity:
```shell
az keyvault set-policy --name $KEYVAULT_NAME --object-id $USER_ASSIGNED_OBJ_ID --secret-permissions get list --key-permissions get list --certificate-permissions get list
```

### Database Query or Access
Our AKS deployed .NET Application uses the passwordless connection string with a configuration value of Authentication="Active Directory Default".This is received from KeyVault in Form of a Secret. 
The DefaultAzureCredential applies the managed identity that is associated with the hosted app / pod. 
The Workload Identity receives role "Key Vault Secrets User" and we assign access policy to KeyVault for the Workload Identity to get & list secrets.
In order for the App to be authenticated to the Azure SQL DB we need to have a user within the SQL Database for the workload identity.
[Azure SQL Dotnet Quickstart](https://learn.microsoft.com/en-us/azure/azure-sql/database/azure-sql-dotnet-quickstart?view=azuresql)


Download [Azure Data Studio](https://learn.microsoft.com/en-us/azure-data-studio/download-azure-data-studio) and Check for the Workload Identity User to be in the Database. 
Make sure you are ADMIN of the SQL Server to connect and Query.
```sql
SELECT * FROM sys.database_principals
```

## Issue Creation Guidelines
1. Use a Clear and Descriptive Title.
2. Provide Detailed Descriptions of what happened
   1. Describe the issue.
   2. What were you expecting?
   3. Provide a clear and reproducible step-by-step guide to recreate the issue.
   4. Mention relevant versions like browser, OS, or application version.
3. Attach Screenshots
4. Be Polite
5. Suggest Possible Solutions (Optional)

