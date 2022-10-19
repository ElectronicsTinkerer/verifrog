/**
 * Simple hash table implementation in c
 * Zach Baldwin October 2020
 */

#ifndef HASHTABLE_H
#define HASHTABLE_H

#include <string.h> // memcpy()
#include <stdlib.h>
#include <stddef.h> // NULL

#define HASHTABLE_DEFAULT_MAX_POSITIVE_LOAD_FACTOR_VARIANCE 0.2
#define HASHTABLE_DEFAULT_MAX_NGATIVE_LOAD_FACTOR_VARIANCE 0.5
#define HASHTABLE_DEFAULT_LOAD_FACTOR 1.0
#define HASHTABLE_INITIAL_SIZE 16

typedef struct hashtable_t 
{
    float currentLoadFactor;            // Load factor
    unsigned int numberOfItemsInTable;  // Number of items in the table
    unsigned int numberOfSlotsUsed;     // Number of table slots that have had data in them ("dirty slots")
    unsigned int arraySize;             // Current size of array to store elements
    struct hashtable_entry_t **table;   // The table in which to store the elements
} hashtable_t;

typedef struct hashtable_entry_t
{
    struct hashtable_entry_t *next;     // Using collision lists, this points to the next node in the list
    unsigned long key;
    void *value;
} hashtable_entry_t;

typedef struct hashtable_itr_t
{
    int currentTableIndex;
    int foundElements;
    int totalElements;
    int tableSize;
    struct hashtable_entry_t *currentNode;
    struct hashtable_entry_t **iteratorTable;
} hashtable_itr_t;


// Function Prototypes
int hashtable_init(hashtable_t **table);
void hashtable_clear(hashtable_t *table);
void hashtable_put(hashtable_t *table, unsigned long key, void *value);
void hashtable_sput(hashtable_t *table, char *key, void *value);
void *hashtable_get(hashtable_t *table, unsigned long key);
void *hashtable_sget(hashtable_t *table, char *key);
void *hashtable_remove(hashtable_t *table, unsigned long key);
void *hashtable_sremove(hashtable_t *table, char *key);
unsigned int hashtable_contains_key(hashtable_t *table, unsigned long key);
unsigned int hashtable_contains_skey(hashtable_t *table, char *key);
void hashtable_destroy(hashtable_t **table);
unsigned int hashtable_is_empty(hashtable_t *table);
unsigned int hashtable_get_num_elements(hashtable_t *table);
unsigned long hashtable_hash_string(const char *string);
static unsigned int _hashtable_compute_index(hashtable_t *table, unsigned long key);
// static float _hashtable_get_collision_average(hashtable_t *table);
static float _hashtable_get_load_factor(hashtable_t *table);
static void _hashtable_double_table(hashtable_t *table);
static void _hashtable_half_table(hashtable_t *table);

hashtable_itr_t *hashtable_create_iterator(hashtable_t *table);
int hashtable_iterator_has_next(hashtable_itr_t *itr);
hashtable_entry_t *hashtable_iterator_next(hashtable_itr_t *itr);
void hashtable_iterator_free(hashtable_itr_t **itr);


#endif
