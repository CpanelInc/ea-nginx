# Building NGINX modules as an EA4 package

## The Problem

Initially we had to do “source balls” and have ea-nginx build and own the `.so`s.

That is because NGINX does not have a thing like `apxs`.

## The Solution

You can build an NGINX module as long as you have all the info about how its `nginx` was built.

Unfotunately we can’t `BuildRequires: ea-nginx` so that we can `nginx -V` to get the info we need because its install calls cPanel code (which is not available on OBS).

Enter `ea-nginx-ngxdev`.

It will always have the correct info for its version `ea-nginx`, consumers won’t have to call `nginx` and parse its output at build time, consumers will be rebuilt when `ea-nginx` is updated.

That means an NGINX module package can simply:

1. `BuildRequires:  ea-nginx-ngxdev`
2. Build it:
```
# You will be in ./nginx-build after this source()
#    so that configure and make etc can happen.
# We probably want to popd back when we are done in there
. /opt/cpanel/ea-nginx-ngxdev/set_NGINX_CONFIGURE_array.sh
./configure "${NGINX_CONFIGURE[@]}" --add-dynamic-module=../nginx
make %{?_smp_mflags}
popd
```
3. Install it:
```
mkdir -p %{buildroot}%{_libdir}/nginx/modules
install ./nginx-build/objs/ngx_my_module.so %{buildroot}%{_libdir}/nginx/modules/ngx_my_module.so
```
4. Own it:
```
%attr(0755,root,root) %{_libdir}/nginx/modules/ngx_my_module.so
```

Now the package can own the config and the `.so` like normal packages do.
