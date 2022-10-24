/**
 * VeriFrog event definitions
 * 
 * Zach Baldwin
 * 2022-10-18
 */

#include <stdlib.h>

#include "event.h"

/**
 * Free the event struct itself. *e will be NULL following
 * the operation. 
 * NOTE: Does not free the sets/xpcts lists of the event.
 * 
 * @param **e Pointer to the struct to be free'd
 * @return none
 */
void event_destroy(event_t **e) {
    free (*e);
    *e = NULL;
}

