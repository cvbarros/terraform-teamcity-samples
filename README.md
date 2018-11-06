# terraform-teamcity-samples
How to run these samples:

1. Clone this repo yo your machine.
1. Run TeamCity in a docker container and wait for it to initialize. One simple way to do is by using `docker-compose` from this repo:

```bash
> docker-compose up -d
```
3. Navigate to http://localhost:8112 and setup an initial admin user.
4. Set teamcity credentials, matching the user created in the environment:

```bash
> export TEAMCITY_USER=admin
> export TEAMCITY_PASSWORD=admin
```
5. Install the `terraform-provider-teamcity` as per [instructions](https://github.com/cvbarros/terraform-provider-teamcity#using-the-provider).
6. `cd` into the sample folder and run `terraform init`
7. `terraform plan` to preview changes
8. `terraform apply` to apply the configuration.

If variables are needed for samples, you can also export them for your convenience in the environment directly by the following pattern:

```bash
> export TF_VAR_variable_name=foo
```

Before running plan/apply cycles.

# Any problems?
Please file in an issue on the repo :)

