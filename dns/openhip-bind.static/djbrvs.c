/* djbrvs.c
 *
 * Spit out a djbdns-friendly version of an rvs server.
 *
 * JLH 5/9/16
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

main(int argc, char **argv) {
	char *c1;
	char *c2;
	if (argc != 2) {
		/* print something */
		return;
	}
	printf("%s\n", argv[1]);
	c1 = argv[1];
	c2 = c1;
	while (c2 != NULL) {
		c2 = strchr(c1,'.');
		if (c2 != NULL) {
			*c2 = '\0';
		}
		printf("\\%03o", strlen(c1));
		while (*c1 != '\0') {
			printf("\\%03o", *c1);
			c1++;
		}
		c1++;
	}
	printf("\\000\n");
	return;
}

	

