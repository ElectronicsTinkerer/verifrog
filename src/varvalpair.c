/**
 * VeriFrog variable/value pair data structure
 * 
 * Zach Baldwin
 * Fall 2022
 */

#include <stdlib.h>

#include "varvalpair.h"

/**
 * Free the variable and value strings of a varval pair and 
 * free the varval struct itself. *vv will be NULL following
 * the operation.
 * 
 * @param **vv Pointer to thestruct to be free'd
 * @return none
 */
void varval_destroy(varval_t **vv) {
    if ((*vv)->var) free((*vv)->var);
    if ((*vv)->val) free((*vv)->val);
    free(*vv);
    *vv = NULL;
}


