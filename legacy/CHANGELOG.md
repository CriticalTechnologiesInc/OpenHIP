# Hacking OpenHIP to work with OpenSSL v1.1.X

DISCLAIMER: This does not produce a functioning HIP binary. Segfaults occur while attempting to run the 'hip' binary. The 'hitgen' binary functions just fine and creates all the necessary files.

This documented was created by Adam Wiethuechter and Jim Henrickson of Critical Technologies Inc. (CTI) during their struggles to get OpenHIP to work on Ubuntu 18.04 LTS which has OpenSSL 1.1.0g installed on it by default.

There is a patch folder ('openhip-patch/') that has a script to automatically patch OpenHIP included for you to use/consult. To run it do the following:

```
cd /path/to/openhip-patch/
sudo chmod +x *.sh
./openhip-patch.sh /path/to/openhip/source/
```

The documentation that follows is cleaned up notes from the build process that we hope someone will find helpful.

## Installing

```
sudo apt install pkg-config libxml2 libxml2-dev gcc g++ make automake autoconf binutils openssh-server openssl libssl-dev
sudo apt install zip unzip
```

We used the source of OpenHIP using the [branch named _hipv2_](https://bitbucket.org/openhip/openhip/overview) as of 2019-03-20. This specifically was commit "7ca0bd5".

## Building

```
unzip /path/to/openhip/source.zip
cd /path/to/openhip/source/
./bootstrap.sh
./configure
make
```

## Fixing Errors

When fixing errors there is the resource of the 'diff' directory.
This directory is structured holding all the files changed during the below errors and contain the following files:

- A original copy (\*.orig) from the original OpenHIP base.
- A new changed copy that was used to make a functional build.
- A diff file (\*.diff) that is a diff of the new and original files using the following command:

```
diff <changed-file> <original-file> > <filename>.diff
```

Envoked in this way the content in the diff file is as follows:

- The "<" mark before a line indicates the line comes from the changed file
- The ">" mark before a line indicated the line comes from the original file

This can be a valuable reference to see exactly what changed and on what lines.
The originals are also included to perform your own diffs/searches as desired for debugging.

All original make output errors in raw form are located in 'errors/' numbered in order to when they were encountered.
The file uses the file name as a header to reference this original raw file.

### Error 1

**FILE AFFECTED: src/util/hitgen.c**

```
util/hitgen.c: In function ‘generate_HI’:
util/hitgen.c:138:7: error: ‘DSA_generate_parameters’ is deprecated [-Werror=deprecated-declarations]
       dsa = DSA_generate_parameters(opts->bitsize, seed, sizeof(seed),
       ^~~
In file included from /usr/include/openssl/asn1.h:15:0,
                 from /usr/include/openssl/dh.h:18,
                 from /usr/include/openssl/dsa.h:31,
                 from util/hitgen.c:39:
/usr/include/openssl/dsa.h:122:1: note: declared here
 DEPRECATEDIN_0_9_8(DSA *DSA_generate_parameters(int bits,
 ^
util/hitgen.c:156:7: error: ‘RSA_generate_key’ is deprecated [-Werror=deprecated-declarations]
       rsa = RSA_generate_key(opts->bitsize, e, cb, stdout);
       ^~~
In file included from /usr/include/openssl/rsa.h:13:0,
                 from util/hitgen.c:40:
/usr/include/openssl/rsa.h:193:1: note: declared here
 DEPRECATEDIN_0_9_8(RSA *RSA_generate_key(int bits, unsigned long e, void
 ^
util/hitgen.c:212:65: error: dereferencing pointer to incomplete type ‘DSA {aka struct dsa_st}’
       xmlNewChild(hi, NULL, BAD_CAST "P", BAD_CAST BN_bn2hex(dsa->p));
                                                                 ^~
util/hitgen.c:221:65: error: dereferencing pointer to incomplete type ‘RSA {aka struct rsa_st}’
       xmlNewChild(hi, NULL, BAD_CAST "N", BAD_CAST BN_bn2hex(rsa->n));
                                                                 ^~
```

This error is pointing out that the functions used to generate the parameters for DSA and the generate key function for RSA have become deprecated in OpenSSL.
During this build we are running **OpenSSL version 1.1.0g**.

The way we fixed this is by digging into the OpenSSL source code found on GitHub [here](https://github.com/openssl/openssl).
Under the 'crypto' directory there are two major files we looked into: 'dsa/dsa_depr.c' and 'rsa/rsa_depr.c'.

These files contained two functions that were of interest to us:

```
// FROM dsa_depr.c
DSA *DSA_generate_parameters(int bits,
                             unsigned char *seed_in, int seed_len,
                             int *counter_ret, unsigned long *h_ret,
                             void (*callback) (int, int, void *),
                             void *cb_arg)
{
    BN_GENCB *cb;
    DSA *ret;

    if ((ret = DSA_new()) == NULL)
        return NULL;
    cb = BN_GENCB_new();
    if (cb == NULL)
        goto err;

    BN_GENCB_set_old(cb, callback, cb_arg);

    if (DSA_generate_parameters_ex(ret, bits, seed_in, seed_len,
                                   counter_ret, h_ret, cb)) {
        BN_GENCB_free(cb);
        return ret;
    }
    BN_GENCB_free(cb);
err:
    DSA_free(ret);
    return NULL;
}

// FROM rsa_depr.c
RSA *RSA_generate_key(int bits, unsigned long e_value,
                      void (*callback) (int, int, void *), void *cb_arg)
{
    int i;
    BN_GENCB *cb = BN_GENCB_new();
    RSA *rsa = RSA_new();
    BIGNUM *e = BN_new();

    if (cb == NULL || rsa == NULL || e == NULL)
        goto err;

    /*
     * The problem is when building with 8, 16, or 32 BN_ULONG, unsigned long
     * can be larger
     */
    for (i = 0; i < (int)sizeof(unsigned long) * 8; i++) {
        if (e_value & (1UL << i))
            if (BN_set_bit(e, i) == 0)
                goto err;
    }

    BN_GENCB_set_old(cb, callback, cb_arg);

    if (RSA_generate_key_ex(rsa, bits, e, cb)) {
        BN_free(e);
        BN_GENCB_free(cb);
        return rsa;
    }
 err:
    BN_free(e);
    RSA_free(rsa);
    BN_GENCB_free(cb);
    return 0;
}
```

These two functions allow us to bypass the deprecated function calls and take the work out of sorting out how to call the new types.

So in the file 'src/util/hitgen.c' we copy and pasted these functions (appending a "my_" to the beginning of them) near the top of the file and called them instead.

This removed the errors during the make and we continued.

Here is the full changes parsed out here:

```
DSA *my_DSA_generate_parameters(int bits,
                             unsigned char *seed_in, int seed_len,
                             int *counter_ret, unsigned long *h_ret,
                             void (*callback) (int, int, void *),
                             void *cb_arg)
{
    ...
}

RSA *my_RSA_generate_key(int bits, unsigned long e_value,
                      void (*callback) (int, int, void *), void *cb_arg)
{
    ...
}

dsa = my_DSA_generate_parameters(opts->bitsize, seed, sizeof(seed),
                              NULL, NULL, cb, stdout);

rsa = my_RSA_generate_key(opts->bitsize, e, cb, stdout);
```

### Errors 2 - 4

**FILE AFFECTED: src/util/hitgen.c**

```
util/hitgen.c: In function ‘generate_HI’:
util/hitgen.c:162:60: error: passing argument 3 of ‘RSA_generate_key_ex’ makes pointer from integer without a cast [-Werror=int-conversion]
       int retRSA = RSA_generate_key_ex(rsa, opts->bitsize, e, NULL);
                                                            ^
In file included from util/hitgen.c:40:0:
/usr/include/openssl/rsa.h:198:5: note: expected ‘BIGNUM * {aka struct bignum_st *}’ but argument is of type ‘long unsigned int’
 int RSA_generate_key_ex(RSA *rsa, int bits, BIGNUM *e, BN_GENCB *cb);
     ^~~~~~~~~~~~~~~~~~~
util/hitgen.c:140:11: error: unused variable ‘dsaRet’ [-Werror=unused-variable]
       int dsaRet = DSA_generate_parameters_ex(dsa, opts->bitsize, seed, sizeof(seed),
           ^~~~~~
util/hitgen.c:220:65: error: dereferencing pointer to incomplete type ‘DSA {aka struct dsa_st}’
       xmlNewChild(hi, NULL, BAD_CAST "P", BAD_CAST BN_bn2hex(dsa->p));
                                                                 ^~
util/hitgen.c:229:65: error: dereferencing pointer to incomplete type ‘RSA {aka struct rsa_st}’
       xmlNewChild(hi, NULL, BAD_CAST "N", BAD_CAST BN_bn2hex(rsa->n));
                                                                 ^~
```

We will break this error up into two parts.

#### Part 1
```
util/hitgen.c:162:60: error: passing argument 3 of ‘RSA_generate_key_ex’ makes pointer from integer without a cast [-Werror=int-conversion]
       int retRSA = RSA_generate_key_ex(rsa, opts->bitsize, e, NULL);
                                                            ^
In file included from util/hitgen.c:40:0:
/usr/include/openssl/rsa.h:198:5: note: expected ‘BIGNUM * {aka struct bignum_st *}’ but argument is of type ‘long unsigned int’
 int RSA_generate_key_ex(RSA *rsa, int bits, BIGNUM *e, BN_GENCB *cb);
     ^~~~~~~~~~~~~~~~~~~
util/hitgen.c:140:11: error: unused variable ‘dsaRet’ [-Werror=unused-variable]
 int dsaRet = DSA_generate_parameters_ex(dsa, opts->bitsize, seed, sizeof(seed),
     ^~~~~~
```

This is left over from when we were playing with attempting to code in the new way of calling the functions definitions by hand before Jim found the solution in Error 3. Should be safe to ignore this bit (you probably won't get this error).

#### Part 2
```
util/hitgen.c:220:65: error: dereferencing pointer to incomplete type ‘DSA {aka struct dsa_st}’
       xmlNewChild(hi, NULL, BAD_CAST "P", BAD_CAST BN_bn2hex(dsa->p));
                                                                 ^~
util/hitgen.c:229:65: error: dereferencing pointer to incomplete type ‘RSA {aka struct rsa_st}’
       xmlNewChild(hi, NULL, BAD_CAST "N", BAD_CAST BN_bn2hex(rsa->n));
```

These lines pointed to a larger issue that persists over the whole OpenHIP source code.

In the past OpenSSL's structs RSA, DSA, DH and others were opaque in nature. That is we could easily access the member elements through the "->" notation. However starting in OpenSSL 1.1.X this was no longer allowed and a new style appeared. This style consists of setter and getter functions for the various structures in OpenSSL.

The errors above are complaining about how the "->" operation is no longer a valid way to access the elements.

Instead the following kind of operation has to be done instead:

```
const BIGNUM *dsa_p, *dsa_q, *dsa_g, *dsa_pub_key, *dsa_priv_key;
DSA_get0_pqg(dsa, &dsa_p, &dsa_q, &dsa_g);
xmlNewChild(hi, NULL, BAD_CAST "P", BAD_CAST BN_bn2hex(dsa_p));
xmlNewChild(hi, NULL, BAD_CAST "Q", BAD_CAST BN_bn2hex(dsa_q));
xmlNewChild(hi, NULL, BAD_CAST "G", BAD_CAST BN_bn2hex(dsa_g));
```

The new getter and setter functions for DSA is defined as follows:

```
void DSA_get0_pqg(const DSA *d, const BIGNUM **p, const BIGNUM **q, const BIGNUM **g);
int DSA_set0_pqg(DSA *d, BIGNUM *p, BIGNUM *q, BIGNUM *g);
void DSA_get0_key(const DSA *d, const BIGNUM **pub_key, const BIGNUM **priv_key);
int DSA_set0_key(DSA *d, BIGNUM *pub_key, BIGNUM *priv_key);
```

To use this function we must pass in the DSA we are accessing. The other three arguments are passing in a variable by reference to fill them with the required value. If the function finds the value to be NULL then it ignores the argument and will not pass the value back.

RSA has a similar functions defined as follows:

```
int RSA_set0_key(RSA *r, BIGNUM *n, BIGNUM *e, BIGNUM *d);
int RSA_set0_factors(RSA *r, BIGNUM *p, BIGNUM *q);
int RSA_set0_crt_params(RSA *r,BIGNUM *dmp1, BIGNUM *dmq1, BIGNUM *iqmp);
void RSA_get0_key(const RSA *r, const BIGNUM **n, const BIGNUM **e, const BIGNUM **d);
void RSA_get0_factors(const RSA *r, const BIGNUM **p, const BIGNUM **q);
void RSA_get0_crt_params(const RSA *r, const BIGNUM **dmp1, const BIGNUM **dmq1, const BIGNUM **iqmp);
```

As you can see this follows a very similar pattern.

Note how the "sets" don't require a "const" but "gets" do. We will see an example of "set" later.

Below is the block with changes made to it:

```
const BIGNUM *dsa_p, *dsa_q, *dsa_g, *dsa_pub_key, *dsa_priv_key;
const BIGNUM *rsa_n, *rsa_e, *rsa_d, *rsa_p, *rsa_q, *rsa_dmp1, *rsa_dmq1, *rsa_iqmp;
switch (opts->type)
{
case HI_ALG_DSA:
  DSA_get0_pqg(dsa, &dsa_p, &dsa_q, &dsa_g);
  xmlNewChild(hi, NULL, BAD_CAST "P", BAD_CAST BN_bn2hex(dsa_p));
  xmlNewChild(hi, NULL, BAD_CAST "Q", BAD_CAST BN_bn2hex(dsa_q));
  xmlNewChild(hi, NULL, BAD_CAST "G", BAD_CAST BN_bn2hex(dsa_g));
  DSA_get0_key(dsa, &dsa_pub_key, &dsa_priv_key);
  xmlNewChild(hi, NULL, BAD_CAST "PUB",
              BAD_CAST BN_bn2hex(dsa_pub_key));
  xmlNewChild(hi, NULL,BAD_CAST "PRIV",
              BAD_CAST BN_bn2hex(dsa_priv_key));
  break;
case HI_ALG_RSA:
  RSA_get0_key(rsa, &rsa_n, &rsa_e, &rsa_d);
  xmlNewChild(hi, NULL, BAD_CAST "N", BAD_CAST BN_bn2hex(rsa_n));
  xmlNewChild(hi, NULL, BAD_CAST "E", BAD_CAST BN_bn2hex(rsa_e));
  xmlNewChild(hi, NULL, BAD_CAST "D", BAD_CAST BN_bn2hex(rsa_d));
  RSA_get0_factors(rsa, &rsa_p, &rsa_q);
  xmlNewChild(hi, NULL, BAD_CAST "P", BAD_CAST BN_bn2hex(rsa_p));
  xmlNewChild(hi, NULL, BAD_CAST "Q", BAD_CAST BN_bn2hex(rsa_q));
  RSA_get0_crt_params(rsa, &rsa_dmp1, &rsa_dmq1, &rsa_iqmp);
  xmlNewChild(hi, NULL, BAD_CAST "dmp1",
              BAD_CAST BN_bn2hex(rsa_dmp1));
  xmlNewChild(hi, NULL, BAD_CAST "dmq1",
              BAD_CAST BN_bn2hex(rsa_dmq1));
  xmlNewChild(hi, NULL, BAD_CAST "iqmp",
              BAD_CAST BN_bn2hex(rsa_iqmp));
  break;
```

### Error 5

**FILE AFFECTED: src/util/hip_util.c**

```
util/hip_util.c: In function ‘key_data_to_hi’:
util/hip_util.c:532:14: error: dereferencing pointer to incomplete type ‘DSA {aka struct dsa_st}’
       hi->dsa->q = BN_bin2bn(&data[offset], DSA_PRIV, 0);
              ^~
util/hip_util.c:549:14: error: dereferencing pointer to incomplete type ‘RSA {aka struct rsa_st}’
       hi->rsa->e = BN_bin2bn(&data[offset], e_len, 0);
              ^~
util/hip_util.c: In function ‘init_crypto’:
util/hip_util.c:3158:3: error: implicit declaration of function ‘CRYPTO_malloc_init’; did you mean ‘CRYPTO_malloc’? [-Werror=implicit-function-declaration]
   CRYPTO_malloc_init();
   ^~~~~~~~~~~~~~~~~~
   CRYPTO_malloc
```

We will approach this in parts again.
All changes here are done in 'src/util/hip_util.c'.

#### Part 1
```
util/hip_util.c:532:14: error: dereferencing pointer to incomplete type ‘DSA {aka struct dsa_st}’
       hi->dsa->q = BN_bin2bn(&data[offset], DSA_PRIV, 0);
              ^~
util/hip_util.c:549:14: error: dereferencing pointer to incomplete type ‘RSA {aka struct rsa_st}’
       hi->rsa->e = BN_bin2bn(&data[offset], e_len, 0);
              ^~
```

This is the exact issue we had with Errors 2 - 4, Part 2 above. We can no longer reference RSA and DSA struct parameters with the "->" syntax.

Here is the blocks with the changes made:

```
BIGNUM *dsa_p, *dsa_q, *dsa_g, *dsa_pub_key;
BIGNUM *rsa_n, *rsa_e;
/* read algorithm-specific key data */
switch (alg)
  {
  case HI_ALG_DSA:
    hi->dsa = DSA_new();
    /* get Q, P, G, and Y */
    offset = 1;
    dsa_q = BN_bin2bn(&data[offset], DSA_PRIV, 0);
    offset += DSA_PRIV;
    dsa_p = BN_bin2bn(&data[offset], key_len, 0);
    offset += key_len;
    dsa_g = BN_bin2bn(&data[offset], key_len, 0);
    offset += key_len;
    DSA_set0_pqg(hi->dsa, dsa_p, dsa_q, dsa_g);
    dsa_pub_key = BN_bin2bn(&data[offset], key_len, 0);
    DSA_set0_key(hi->dsa, dsa_pub_key, NULL);
#ifndef HIP_VPLS
    log_(NORM, "Found DSA HI with public key: 0x");
    print_hex((char *)&data[offset], key_len);
    log_(NORM, "\n");
#endif
    offset += key_len;
    break;
  case HI_ALG_RSA:
    hi->rsa = RSA_new();
    offset = ((e_len > 255) ? 3 : 1);
    rsa_e = BN_bin2bn(&data[offset], e_len, 0);
    offset += e_len;
    rsa_n = BN_bin2bn(&data[offset], key_len, 0);
#ifndef HIP_VPLS
    log_(NORM, "Found RSA HI with public modulus: 0x");
    print_hex((char *)&data[offset], key_len);
    log_(NORM, "\n");
#endif
    offset += key_len;
    RSA_set0_key(hi->rsa, rsa_n, rsa_e, NULL);
    break;
```

Notice how the above block uses "set0" instead of "get0" and the changes made to the various variable types and how the parameters are passed.

```
const BIGNUM *dsa_p, *dsa_q, *dsa_g, *dsa_pub_key;
const BIGNUM *rsa_n, *rsa_e;

switch (hi->algorithm_id)
  {
  case HI_ALG_DSA:     /* RFC 2536 */
    /* Encode T, Q, P, G, Y */
    location = 0;
    out[location] = (hi->size - 64) / 8;
    location++;
    DSA_get0_pqg(hi->dsa, &dsa_p, &dsa_q, &dsa_g);
    DSA_get0_key(hi->dsa, &dsa_pub_key, NULL);
    bn2bin_safe(dsa_q, &out[location], DSA_PRIV);
    bn2bin_safe(dsa_p, &out[location + DSA_PRIV], hi->size);
    bn2bin_safe(dsa_g, &out[location + DSA_PRIV + hi->size],
                hi->size);
    bn2bin_safe(dsa_pub_key,
                &out[location + DSA_PRIV + (2 * hi->size)],
                hi->size);
    break;
  case HI_ALG_RSA:     /* RFC 3110 */
    /* Encode e_len, exponent(e), modulus(n) */
    location = 0;
    RSA_get0_key(hi->rsa, &rsa_n, &rsa_e, NULL);
    e_len = BN_num_bytes(rsa_e);
    if (e_len > 255)
      {
        __u16 *p =  (__u16*) &out[location + 1];
        out[location] = 0x0;
        *p = htons(e_len);
        location += 3;
      }
    else
      {
        out[location] = (__u8) e_len;
        location++;
      }
    location += bn2bin_safe(rsa_e, &out[location], e_len);
    location += bn2bin_safe(rsa_n, &out[location],
                            RSA_size(hi->rsa));
    break;
```

```
const BIGNUM *rsa_e;
/* calculate lengths and validate HIs */
switch (hi->algorithm_id)
  {
  case HI_ALG_DSA:     /* RFC 2536 */
    ...
  case HI_ALG_RSA:     /* RFC 3110 */
    if (!hi->rsa)
      {
        log_(WARN, "hi_to_hit(): NULL rsa\n");
        return(-1);
      }
    len = sizeof(khi_context_id);
    RSA_get0_key(hi->rsa, NULL, &rsa_e, NULL);
    len += BN_num_bytes(rsa_e) + RSA_size(hi->rsa);
    if (BN_num_bytes(rsa_e) > 255)
      {
        len += 3;
      }
    else
      {
        len++;
      }
    break;
```

#### Part 2
```
util/hip_util.c: In function ‘init_crypto’:
util/hip_util.c:3158:3: error: implicit declaration of function ‘CRYPTO_malloc_init’; did you mean ‘CRYPTO_malloc’? [-Werror=implicit-function-declaration]
   CRYPTO_malloc_init();
   ^~~~~~~~~~~~~~~~~~
   CRYPTO_malloc
```

For this we simply commented out the call.

It is unknown if this important, however switching it to the compiler suggested "CRYPTO_malloc" requires parameters we do not understand.

### Error 6

**FILE AFFECTED: include/hip/hip_sadb.h**

```
In file included from linux/hip_linux_umh.c:65:0:
./include/hip/hip_sadb.h:128:3: error: unknown type name ‘des_key_schedule’
   des_key_schedule ks[3];               /* 3-DES keys */
   ^~~~~~~~~~~~~~~~
```

Here we have another change is OpenSSL. Here it is merely a naming convention of using "DES" instead if "des".

### Error 7

**FILE AFFECTED: src/protocol/hip_cache.c**

```
protocol/hip_cache.c: In function ‘new_dh_cache_entry’:
protocol/hip_cache.c:415:7: error: dereferencing pointer to incomplete type ‘DH {aka struct dh_st}’
     dh->g = BN_new();
       ^~
```

Another example of the same error type as Errors 2 - 4, Part 2.

Below is the changes made:

```
if(ec_curve_nid[group_id]) { // check if eliptic curve diffie-hellman
  ...
}
else
{
  DH *dh = DH_new();
  BIGNUM *dh_p, *dh_g;
  dh_g = BN_new();
  dh_p = BN_new();
  /* Put prime corresponding to group_id into dh->p */
  BN_bin2bn(dhprime[group_id],
            dhprime_len[group_id], dh_p);
  /* Put generator corresponding to group_id into dh->g */
  BN_set_word(dh_g, dhgen[group_id]);
  /* By not setting dh->priv_key, allow crypto lib to pick at random */
  DH_set0_pqg(dh, dh_p, NULL, dh_g);
  if ((err = DH_generate_key(dh)) != 1)
  {
    log_(ERR, "DH key generation failed %d.\n", group_id);
    log_(NORMT, "DH key generation failed.\n");
    exit(1);
  }

  EVP_PKEY_assign_DH(entry->evp_dh, dh);
}
```

### Error 8

**FILE AFFECTED: src/protocol/hip_dht.c**

```
protocol/hip_dht.c: In function ‘hip_xmlrpc_parse_response’:
protocol/hip_dht.c:1332:18: error: storage size of ‘ctx’ isn’t known
   EVP_ENCODE_CTX ctx;
                  ^~~
protocol/hip_dht.c:1332:18: error: unused variable ‘ctx’ [-Werror=unused-variable]
```

This error is pointing to how the variable "ctx" is initialized.

We must now perform an action such as the following:

```
EVP_ENCODE_CTX *ctx;
ctx = EVP_ENCODE_CTX_new();
if (!ctx)
{
  printf("Failed to init CTX!\n");
}
```

We could get fancier to handle the failure, but this at least allows the error to be removed.

Another area that will need changing because of this is below. You will have to dereference "ctx" by removing the "&" in the shown locations.

```
/* step through array of responses */
for (node = node->children; node; node = node->next)
{
  ...
  EVP_DecodeInit(ctx);
  retval = EVP_DecodeUpdate(ctx, (__u8 *)value, &i,
                            (__u8 *)data,
                            strlen((char *)data));
  ...
  EVP_DecodeFinal(ctx, data, &i);
  ...
}
```

### Error 9-10

**FILE AFFECTED: src/protocol/hip_input.c**

```
protocol/hip_input.c: In function ‘validate_signature’:
protocol/hip_input.c:3788:11: error: storage size of ‘dsa_sig’ isn’t known
   DSA_SIG dsa_sig;
           ^~~~~~~
protocol/hip_input.c:3789:13: error: storage size of ‘ecdsa_sig’ isn’t known
   ECDSA_SIG ecdsa_sig;
             ^~~~~~~~~
protocol/hip_input.c:3789:13: error: unused variable ‘ecdsa_sig’ [-Werror=unused-variable]
protocol/hip_input.c:3788:11: error: unused variable ‘dsa_sig’ [-Werror=unused-variable]
   DSA_SIG dsa_sig;
           ^~~~~~~
protocol/hip_input.c: In function ‘handle_dh’:
protocol/hip_input.c:4224:51: error: dereferencing pointer to incomplete type ‘EVP_PKEY {aka struct evp_pkey_st}’
     log_(NORM, "EVP_PKEY type: %d", hip_a->peer_dh->type);
                                                   ^~
```

#### Part 1
```
protocol/hip_input.c: In function ‘validate_signature’:
protocol/hip_input.c:3788:11: error: storage size of ‘dsa_sig’ isn’t known
   DSA_SIG dsa_sig;
           ^~~~~~~
protocol/hip_input.c:3789:13: error: storage size of ‘ecdsa_sig’ isn’t known
   ECDSA_SIG ecdsa_sig;
             ^~~~~~~~~
protocol/hip_input.c:3789:13: error: unused variable ‘ecdsa_sig’ [-Werror=unused-variable]
protocol/hip_input.c:3788:11: error: unused variable ‘dsa_sig’ [-Werror=unused-variable]
   DSA_SIG dsa_sig;
           ^~~~~~~
```
This is just like Error 8 above.

Below is the blcoks of changes:

```
DSA_SIG *dsa_sig;
dsa_sig = DSA_SIG_new();
if (!dsa_sig)
{
  printf("DSA SIG not allocated!\n");
}
ECDSA_SIG *ecdsa_sig;
ecdsa_sig = ECDSA_SIG_new();
if (!ecdsa_sig)
{
  printf("ECDSA SIG not allocated!\n");
}
```

```
BIGNUM *dsa_sig_r, *dsa_sig_s;
BIGNUM *ecdsa_sig_r, *ecdsa_sig_s;
switch (alg)
  {
  case HI_ALG_DSA:
    /* build the DSA structure */
    dsa_sig_r = BN_bin2bn(&sig->signature[1], 20, NULL);
    dsa_sig_s = BN_bin2bn(&sig->signature[21], 20, NULL);
    DSA_SIG_set0(dsa_sig, dsa_sig_r, dsa_sig_s);
    /* verify the DSA signature */
    err = DSA_do_verify(md, SHA256_DIGEST_LENGTH, dsa_sig, dsa);
    BN_free(dsa_sig_r);
    BN_free(dsa_sig_s);
    break;
  case HI_ALG_RSA:
    /* verify the RSA signature */
    err = RSA_verify(NID_sha1, md, SHA256_DIGEST_LENGTH,
                     sig->signature, sig_len, rsa);
    break;
  case HI_ALG_ECDSA:
    {
      int curve_name = ECDSA_get_curve_id(ecdsa);
      if (curve_name == -1) {
        log_(WARN, "Curve not implemented.\n");
        return -1;
      }
      int curve_param_size = ECDSA_curve_PARAM_SIZE[curve_name];
      ecdsa_sig_r = BN_bin2bn(&sig->signature[0], curve_param_size, NULL);
      ecdsa_sig_s = BN_bin2bn(&sig->signature[curve_param_size], curve_param_size, NULL);
      ECDSA_SIG_set0(ecdsa_sig, ecdsa_sig_r, ecdsa_sig_s);
      err = ECDSA_do_verify(md, curve_param_size, ecdsa_sig, ecdsa);
      BN_free(ecdsa_sig_r);
      BN_free(ecdsa_sig_s);
    }
    break;
  default:
    err = -1;
    break;
  }
```

#### Part 2
```
protocol/hip_input.c: In function ‘handle_dh’:
protocol/hip_input.c:4224:51: error: dereferencing pointer to incomplete type ‘EVP_PKEY {aka struct evp_pkey_st}’
     log_(NORM, "EVP_PKEY type: %d", hip_a->peer_dh->type);
                                                   ^~
```
For this error we commented out the line as it seems to be a log function and not needed.

### Error 11

**FILE AFFECTED: src/protocol/hip_output.c**

```
In file included from protocol/hip_output.c:42:0:
protocol/hip_output.c: In function ‘build_tlv_hostid_len’:
protocol/hip_output.c:2099:62: error: dereferencing pointer to incomplete type ‘RSA {aka struct rsa_st}’
       hi_len = sizeof(tlv_host_id) + 1 + BN_num_bytes(hi->rsa->e)
                                                              ^
protocol/hip_output.c: In function ‘build_tlv_hostid’:
protocol/hip_output.c:2162:33: error: dereferencing pointer to incomplete type ‘DSA {aka struct dsa_st}’
       len += bn2bin_safe(hi->dsa->q, &data[len], DSA_PRIV);
                                 ^~
protocol/hip_output.c: In function ‘build_tlv_signature’:
protocol/hip_output.c:2407:26: error: dereferencing pointer to incomplete type ‘DSA_SIG {aka struct DSA_SIG_st}’
       bn2bin_safe(dsa_sig->r, &sig->signature[1], 20);
                          ^~
protocol/hip_output.c:2438:30: error: dereferencing pointer to incomplete type ‘ECDSA_SIG {aka struct ECDSA_SIG_st}’
         bn2bin_safe(ecdsa_sig->r, &sig->signature[0], curve_param_size);
                              ^~
```
We have once again some dereferencing pointer issues like Errors 2 - 4, Part 2.

```
const BIGNUM *rsa_e;
switch (hi->algorithm_id)
  {
  case HI_ALG_DSA:            /*       tlv + T + Q + P,G,Y */
    if (!hi->dsa)
      {
        log_(WARN, "No DSA context when building length!\n");
        return(0);
      }
    hi_len = sizeof(tlv_host_id) + 1 + DSA_PRIV + 3 * hi->size;
    break;
  case HI_ALG_RSA:            /*       tlv + e_len,e + N */
    if (!hi->rsa)
      {
        log_(WARN, "No RSA context when building length!\n");
        return(0);
      }
    RSA_get0_key(hi->rsa, NULL, &rsa_e, NULL);
    hi_len = sizeof(tlv_host_id) + 1 + BN_num_bytes(rsa_e)
             + RSA_size(hi->rsa);
    if (BN_num_bytes(rsa_e) > 255)
      {
        hi_len += 2;
      }
    break;
  case HI_ALG_ECDSA:          /*        tlv + curve_len + public_key_len */
    if (!hi->ecdsa)
      {
        log_(WARN, "No ECDSA context when building length!\n");
        return(0);
      }
      hi_len = sizeof(tlv_host_id) + 2 + HIP_ECDSA384_SIG_SIZE; // TODO: 33 if compressed
    break;

  default:
    break;
  }
```

```
const BIGNUM *dsa_p, *dsa_q, *dsa_g, *dsa_pub_key;
const BIGNUM *rsa_n, *rsa_e;
switch (hi->algorithm_id)
  {
  case HI_ALG_DSA:     /* RDATA word: flags(16), proto(8), alg(8) */
    data[len] = (__u8) (hi->size - 64) / 8;           /* T value (1 byte) */
    len++;
    DSA_get0_pqg(hi->dsa, &dsa_p, &dsa_q, &dsa_g);
    DSA_get0_key(hi->dsa, &dsa_pub_key, NULL);
    len += bn2bin_safe(dsa_q, &data[len], DSA_PRIV);
    len += bn2bin_safe(dsa_p, &data[len], hi->size);
    len += bn2bin_safe(dsa_g, &data[len], hi->size);
    len += bn2bin_safe(dsa_pub_key, &data[len], hi->size);
    break;
  case HI_ALG_RSA:
    RSA_get0_key(hi->rsa, &rsa_n, &rsa_e, NULL);
    e_len = BN_num_bytes(rsa_e);
    ...
    /* public exponent */
    len += bn2bin_safe(rsa_e, &data[len], e_len);
    /* public modulus */
    len += bn2bin_safe(rsa_n, &data[len], RSA_size(hi->rsa));
    break;
  case HI_ALG_ECDSA:
    {
    BN_CTX * bn_ctx = BN_CTX_new();
    const EC_GROUP * ec_group = EC_KEY_get0_group(hi->ecdsa);
    const EC_POINT * ec_point = EC_KEY_get0_public_key(hi->ecdsa);
    ...
    }
  default:
    break;
  }
```

```
const BIGNUM *dsa_sig_r, *dsa_sig_s, *ecdsa_sig_r, *ecdsa_sig_s;
switch (hi->algorithm_id)
  {
  case HI_ALG_DSA:
    ...
    /* build signature from DSA_SIG struct */
    DSA_SIG_get0(dsa_sig, &dsa_sig_r, &dsa_sig_s);
    bn2bin_safe(dsa_sig_r, &sig->signature[1], 20);
    bn2bin_safe(dsa_sig_s, &sig->signature[21], 20);
    DSA_SIG_free(dsa_sig);
    break;
  case HI_ALG_RSA:
    ...
  case HI_ALG_ECDSA: /* RFC 4754 */
    {
      ...
      ECDSA_SIG_get0(ecdsa_sig, &ecdsa_sig_r, &ecdsa_sig_s);
      bn2bin_safe(ecdsa_sig_r, &sig->signature[0], curve_param_size);
      bn2bin_safe(ecdsa_sig_s, &sig->signature[curve_param_size], curve_param_size);

      ECDSA_SIG_free(ecdsa_sig);
      sig_len = 2 * curve_param_size; 
    }
    break;
  default:
    break;
  }
```

### Error 12

**FILE AFFECTED: src/util/hip_xml.c**

```
util/hip_xml.c: In function ‘parse_xml_hostid’:
util/hip_xml.c:270:33: error: dereferencing pointer to incomplete type ‘DSA {aka struct dsa_st}’
               BN_hex2bn(&hi->dsa->p, data);
                                 ^~
util/hip_xml.c:292:33: error: dereferencing pointer to incomplete type ‘RSA {aka struct rsa_st}’
               BN_hex2bn(&hi->rsa->n, data);
                                 ^~
```
Same thing. Note that this paticular block is reading in data from a configuration file and pushing it into our running code.
For both RSA and DSA we need to put the values in BIGNUM variables then use their respective setter to push the value into the structure in OpenSSL.
The "&hi->dsa->p" worked before but now has to be broken up as follows:

```
BIGNUM *dsa_p, *dsa_q, *dsa_g, *dsa_pub_key, *dsa_priv_key;
BIGNUM *rsa_n, *rsa_e, *rsa_d, *rsa_p, *rsa_q, *rsa_dmp1, *rsa_dmq1, *rsa_iqmp;
/* populate the DSA structure */
switch (hi->algorithm_id)
  {
  case HI_ALG_DSA:
    if (strcmp((char *)node->name, "P") == 0)
      {
        BN_hex2bn(&dsa_p, data);
        DSA_set0_pqg(hi->dsa, dsa_p, NULL, NULL);
      }
    else if (strcmp((char *)node->name, "Q") == 0)
      {
        BN_hex2bn(&dsa_q, data);
        DSA_set0_pqg(hi->dsa, NULL, dsa_q, NULL);
      }
    else if (strcmp((char *)node->name, "G") == 0)
      {
        BN_hex2bn(&dsa_g, data);
        DSA_set0_pqg(hi->dsa, NULL, NULL, dsa_g);
      }
    else if (strcmp((char *)node->name, "PUB") == 0)
      {
        BN_hex2bn(&dsa_pub_key, data);
        DSA_set0_key(hi->dsa, dsa_pub_key, NULL);
      }
    else if (strcmp((char *)node->name, "PRIV") == 0)
      {
        BN_hex2bn(&dsa_priv_key, data);
        DSA_set0_key(hi->dsa, NULL, dsa_priv_key);
      }
    break;
  case HI_ALG_RSA:
    if (strcmp((char *)node->name, "N") == 0)
      {
        BN_hex2bn(&rsa_n, data);
        RSA_set0_key(hi->rsa, rsa_n, NULL, NULL);
      }
    else if (strcmp((char *)node->name, "E") == 0)
      {
        BN_hex2bn(&rsa_e, data);
        RSA_set0_key(hi->rsa, NULL, rsa_e, NULL);
      }
    else if (strcmp((char *)node->name, "D") == 0)
      {
        BN_hex2bn(&rsa_d, data);
        RSA_set0_key(hi->rsa, NULL, NULL, rsa_d);
      }
    else if (strcmp((char *)node->name, "P") == 0)
      {
        BN_hex2bn(&rsa_p, data);
        RSA_set0_factors(hi->rsa, rsa_p, NULL);
      }
    else if (strcmp((char *)node->name, "Q") == 0)
      {
        BN_hex2bn(&rsa_q, data);
        RSA_set0_factors(hi->rsa, NULL, rsa_q);
      }
    else if (strcmp((char *)node->name, "dmp1") == 0)
      {
        BN_hex2bn(&rsa_dmp1, data);
        RSA_set0_crt_params(hi->rsa, rsa_dmp1, NULL, NULL);
      }
    else if (strcmp((char *)node->name, "dmq1") == 0)
      {
        BN_hex2bn(&rsa_dmq1, data);
        RSA_set0_crt_params(hi->rsa, NULL, rsa_dmq1, NULL);
      }
    else if (strcmp((char *)node->name, "iqmp") == 0)
      {
        BN_hex2bn(&rsa_iqmp, data);
        RSA_set0_crt_params(hi->rsa, NULL, NULL, rsa_iqmp);
      }
      break;
```

```
if (mine)
{
  const BIGNUM *dsa_p, *dsa_q, *dsa_g, *dsa_pub_key, *dsa_priv_key;
  const BIGNUM *rsa_n, *rsa_e, *rsa_d, *rsa_p, *rsa_q, *rsa_dmp1, *rsa_dmq1, *rsa_iqmp;
  switch (h->algorithm_id)
    {
    case HI_ALG_DSA:
      DSA_get0_pqg(h->dsa, &dsa_p, &dsa_q, &dsa_g);
      DSA_get0_key(h->dsa, &dsa_pub_key, &dsa_priv_key);
      xmlNewChild_from_bn(hi, dsa_p, "P");
      xmlNewChild_from_bn(hi, dsa_q, "Q");
      xmlNewChild_from_bn(hi, dsa_g, "G");
      xmlNewChild_from_bn(hi, dsa_pub_key, "PUB");
      xmlNewChild_from_bn(hi, dsa_priv_key, "PRIV");
      break;
    case HI_ALG_RSA:
      RSA_get0_key(h->rsa, &rsa_n, &rsa_e, &rsa_d);
      RSA_get0_factors(h->rsa, &rsa_p, &rsa_q);
      RSA_get0_crt_params(h->rsa, &rsa_dmp1, &rsa_dmq1, &rsa_iqmp);
      xmlNewChild_from_bn(hi, rsa_n, "N");
      xmlNewChild_from_bn(hi, rsa_e, "E");
      xmlNewChild_from_bn(hi, rsa_d, "D");
      xmlNewChild_from_bn(hi, rsa_p, "P");
      xmlNewChild_from_bn(hi, rsa_q, "Q");
      xmlNewChild_from_bn(hi, rsa_dmp1, "dmp1");
      xmlNewChild_from_bn(hi, rsa_dmq1, "dmq1");
      xmlNewChild_from_bn(hi, rsa_iqmp, "iqmp");
```

### Error 13

**FILE AFFECTED: src/usermode/hip_esp.c**

```
usermode/hip_esp.c: In function ‘hip_esp_encrypt’:
usermode/hip_esp.c:2074:7: error: implicit declaration of function ‘des_ede3_cbc_encrypt’; did you mean ‘DES_ede3_cbc_encrypt’? [-Werror=implicit-function-declaration]
       des_ede3_cbc_encrypt(&in[hdr_len],
       ^~~~~~~~~~~~~~~~~~~~
       DES_ede3_cbc_encrypt
usermode/hip_esp.c:2077:29: error: ‘des_cblock’ undeclared (first use in this function); did you mean ‘DES_cblock’?
                            (des_cblock*)cbc_iv, DES_ENCRYPT);
                             ^~~~~~~~~~
                             DES_cblock
usermode/hip_esp.c:2077:29: note: each undeclared identifier is reported only once for each function it appears in
usermode/hip_esp.c:2077:40: error: expected expression before ‘)’ token
                            (des_cblock*)cbc_iv, DES_ENCRYPT);
                                        ^
usermode/hip_esp.c: In function ‘hip_esp_decrypt’:
usermode/hip_esp.c:2474:29: error: ‘des_cblock’ undeclared (first use in this function); did you mean ‘DES_cblock’?
                            (des_cblock*)cbc_iv, DES_DECRYPT);
                             ^~~~~~~~~~
                             DES_cblock
usermode/hip_esp.c:2474:40: error: expected expression before ‘)’ token
                            (des_cblock*)cbc_iv, DES_DECRYPT);
                                        ^
```

These errors are related to Error 6.

We change the "des" to be "DES" to fix the warnings.

### Error 14

**FILE AFFECTED: src/usermode/hip_esp.c**

```
usermode/hip_esp.c: In function ‘hip_esp_encrypt’:
usermode/hip_esp.c:2076:28: error: incompatible type for argument 4 of ‘DES_ede3_cbc_encrypt’
                            entry->ks[0], entry->ks[1], entry->ks[2],
                            ^~~~~
In file included from usermode/hip_esp.c:63:0:
/usr/include/openssl/des.h:119:6: note: expected ‘DES_key_schedule * {aka struct DES_ks *}’ but argument is of type ‘DES_key_schedule {aka struct DES_ks}’
 void DES_ede3_cbc_encrypt(const unsigned char *input, unsigned char *output,
      ^~~~~~~~~~~~~~~~~~~~
usermode/hip_esp.c:2076:42: error: incompatible type for argument 5 of ‘DES_ede3_cbc_encrypt’
                            entry->ks[0], entry->ks[1], entry->ks[2],
                                          ^~~~~
In file included from usermode/hip_esp.c:63:0:
/usr/include/openssl/des.h:119:6: note: expected ‘DES_key_schedule * {aka struct DES_ks *}’ but argument is of type ‘DES_key_schedule {aka struct DES_ks}’
 void DES_ede3_cbc_encrypt(const unsigned char *input, unsigned char *output,
      ^~~~~~~~~~~~~~~~~~~~
usermode/hip_esp.c:2076:56: error: incompatible type for argument 6 of ‘DES_ede3_cbc_encrypt’
                            entry->ks[0], entry->ks[1], entry->ks[2],
                                                        ^~~~~
In file included from usermode/hip_esp.c:63:0:
/usr/include/openssl/des.h:119:6: note: expected ‘DES_key_schedule * {aka struct DES_ks *}’ but argument is of type ‘DES_key_schedule {aka struct DES_ks}’
 void DES_ede3_cbc_encrypt(const unsigned char *input, unsigned char *output,
      ^~~~~~~~~~~~~~~~~~~~
usermode/hip_esp.c: In function ‘hip_esp_decrypt’:
usermode/hip_esp.c:2473:28: error: incompatible type for argument 4 of ‘DES_ede3_cbc_encrypt’
                            entry->ks[0], entry->ks[1], entry->ks[2],
                            ^~~~~
In file included from usermode/hip_esp.c:63:0:
/usr/include/openssl/des.h:119:6: note: expected ‘DES_key_schedule * {aka struct DES_ks *}’ but argument is of type ‘DES_key_schedule {aka struct DES_ks}’
 void DES_ede3_cbc_encrypt(const unsigned char *input, unsigned char *output,
      ^~~~~~~~~~~~~~~~~~~~
usermode/hip_esp.c:2473:42: error: incompatible type for argument 5 of ‘DES_ede3_cbc_encrypt’
                            entry->ks[0], entry->ks[1], entry->ks[2],
                                          ^~~~~
In file included from usermode/hip_esp.c:63:0:
/usr/include/openssl/des.h:119:6: note: expected ‘DES_key_schedule * {aka struct DES_ks *}’ but argument is of type ‘DES_key_schedule {aka struct DES_ks}’
 void DES_ede3_cbc_encrypt(const unsigned char *input, unsigned char *output,
      ^~~~~~~~~~~~~~~~~~~~
usermode/hip_esp.c:2473:56: error: incompatible type for argument 6 of ‘DES_ede3_cbc_encrypt’
                            entry->ks[0], entry->ks[1], entry->ks[2],
                                                        ^~~~~
In file included from usermode/hip_esp.c:63:0:
/usr/include/openssl/des.h:119:6: note: expected ‘DES_key_schedule * {aka struct DES_ks *}’ but argument is of type ‘DES_key_schedule {aka struct DES_ks}’
 void DES_ede3_cbc_encrypt(const unsigned char *input, unsigned char *output,
      ^~~~~~~~~~~~~~~~~~~~
```

This giant wall of errors is related again to Error 6.

The 'entry' variable is passed into the function 'hip_esp_encrypt' as a pointer. However to access the array "ks" we must reference the variable.

We do this by adding a "&" before every instance of "entry->ks[]" being called.

### Error 15

**FILE AFFECTED: src/usermode/hip_esp.c**

```
In file included from usermode/hip_esp.c:70:0:
usermode/hip_esp.c: In function ‘send_icmp’:
./include/win32/checksum.h:75:14: error: ‘*((void *)&icmp_parameter_problem+26)’ is used uninitialized in this function [-Werror=uninitialized]
       sum += *p++;
              ^~~~
```

This error we could not trace or figure out. There is an inline function (in checksum.h) that is being called.
Looking at the function "send_icmp" in 'src/usermode/hip_esp.c' seems to show no really issues.
By commenting out the line (243 on our build) where the inline function is called the error goes away.

To fix the error we changed the file 'src/Makefile'. We took out the -Werror flag under the CFLAG definition.
We know this is not the right answer but we do not understand how it functions to actually debug.

NOTE: From here to the end the "-Werror" flag is missing.

### Errors 16 - 17

**FILE AFFECTED: src/usermode/hip_sadb.c**

```
usermode/hip_sadb.c: In function ‘hip_sadb_add’:
usermode/hip_sadb.c:393:7: warning: implicit declaration of function ‘des_set_odd_parity’; did you mean ‘DES_set_odd_parity’? [-Wimplicit-function-declaration]
       des_set_odd_parity((des_cblock*)key1);
       ^~~~~~~~~~~~~~~~~~
       DES_set_odd_parity
usermode/hip_sadb.c:393:27: error: ‘des_cblock’ undeclared (first use in this function); did you mean ‘DES_cblock’?
       des_set_odd_parity((des_cblock*)key1);
                           ^~~~~~~~~~
                           DES_cblock
usermode/hip_sadb.c:393:27: note: each undeclared identifier is reported only once for each function it appears in
usermode/hip_sadb.c:393:38: error: expected expression before ‘)’ token
       des_set_odd_parity((des_cblock*)key1);
                                      ^
usermode/hip_sadb.c:394:38: error: expected expression before ‘)’ token
       des_set_odd_parity((des_cblock*)key2);
                                      ^
usermode/hip_sadb.c:395:38: error: expected expression before ‘)’ token
       des_set_odd_parity((des_cblock*)key3);
                                      ^
usermode/hip_sadb.c:396:13: warning: implicit declaration of function ‘des_set_key_checked’; did you mean ‘DES_set_key_checked’? [-Wimplicit-function-declaration]
       err = des_set_key_checked((des_cblock*)key1, entry->ks[0]);
             ^~~~~~~~~~~~~~~~~~~
             DES_set_key_checked
usermode/hip_sadb.c:396:45: error: expected expression before ‘)’ token
       err = des_set_key_checked((des_cblock*)key1, entry->ks[0]);
                                             ^
usermode/hip_sadb.c:397:46: error: expected expression before ‘)’ token
       err += des_set_key_checked((des_cblock*)key2, entry->ks[1]);
                                              ^
usermode/hip_sadb.c:398:46: error: expected expression before ‘)’ token
       err += des_set_key_checked((des_cblock*)key3, entry->ks[2]);
                                              ^
```
This is another side effect of Error 6 and Error 7.
Change all "des" to "DES" and add "&" before the "entry->ks[]" instances.

## Finish Building

From here there should be no errors in the build.

Run the following:

```
sudo make install
```

This should place files in various locations in the system (mainly '/usr/local/') under 'etc/' and 'sbin/'.

With that OpenHIP should be built and ready to configure.

# Configure & Run OpenHIP (BROKEN)

DISCLAIMER: This does not actually work!

```
cd /usr/local/sbin
sudo ./hitgen
sudo ./hitgen -conf
sudo ./hitgen -publish
sudo ./hip -v
```

This should generate our HITs, create configuration files and publish our HIT file.
The final command should fail with a segfault.

This is where we stopped and pursued a different path to work with OpenHIP as we did not have time nor the expertise to get OpenHIP updated to work with newer versions of OpenSSL.

## Contact & Final Words

The information presented here was compiled by Adam Wiethuechter and Jim Henrickson of Critical Technologies Inc. (CTI).
Everything here is free to use without restriction as these are just cleaned up notes.

We hope that this document and the information presented in it, along with the files packaged with it will be helpful to anyone wishing to continue to development of OpenHIP to work with newer versions of OpenSSL.

Contact information is below:

Adam Wiethuechter <adam.wiethuechter@critical.com>
Jim Henrickson <jim.henrickson@critical.com>