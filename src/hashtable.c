/**
 * Simple hash table implementation in c
 * Zach Baldwin October 2020
 */

#include "hashtable.h"

/**
 * Initialize a hashtable struct
 * 
 * @return 0 on success
 *         1 on failure (memory allocation fault)
 *         
 */
int hashtable_init(hashtable_t **table)
{
    (*table) = malloc(sizeof(**table));
    (*table)->arraySize = HASHTABLE_INITIAL_SIZE;
    (*table)->currentLoadFactor = 0;
    (*table)->numberOfItemsInTable = 0;
    (*table)->numberOfSlotsUsed = 0;
    (*table)->table = malloc(sizeof(*((*table)->table)) * (*table)->arraySize);

    if ((*table)->table == NULL)
    {
        return 1;    // Unable to malloc memory
    }
    
    for (int i = 0; i < (*table)->arraySize; i++)
    {
        (*table)->table[i] = NULL;//malloc(sizeof(hashtable_entry_t *));
    }
    return 0;
}


/**
 * Reset the hashtable to its original size and remove the elements from it<br>
 * Note: <code>free()</code>s all elements in table array!
 * 
 * @param table The hashtable to be cleared
 */
void hashtable_clear(hashtable_t *table)
{
    if (table != NULL)
    {
        // Free the elements in the table
        for (int i = 0; i < table->arraySize; i++)
        {
            if (table->table[i])
            {
                free(table->table[i]);
            }
        }
        free(table->table);

        // Create new table
        table->arraySize = HASHTABLE_INITIAL_SIZE;
        table->table = malloc(sizeof(*(table->table)) * table->arraySize);
    }
}


/**
 * Add an element to the hashtable
 * Assumes that you have already malloc()'d the value pointer
 * 
 * @param table The HashTable to be operated upon
 * @param key The key associated with the provided value
 * @param value The value to be associated with the key
 */
void hashtable_put(hashtable_t *table, unsigned long key, void *value)
{
    if (table != NULL)
    {
        unsigned int pointer = _hashtable_compute_index(table, key);

        hashtable_entry_t *item = malloc(sizeof(*item));
        
        item->next = NULL;
        item->value = value;
        item->key = key;

        // If this location in the table is empty, just add the node
        if (table->table[pointer] == NULL)
        {
            table->table[pointer] = item;
            table->numberOfSlotsUsed++;
        }
        else
        {
            hashtable_entry_t *node = table->table[pointer];
            int done = 0;
            while (node != NULL && !done)
            {
                if ((item->key) > (node->key) && node->next == NULL)
                {
                    node->next = item;
                    done = 1;
                }
                else if (node->next != NULL && (item->key) < (node->next->key) && (item->key) > (node->key))
                {
                    item->next = node->next;
                    node->next = item;
                    done = 1;
                }
                else if (item->key < node->key)
                {
                    item->next = node;
                    table->table[pointer] = item;
                    done = 1;
                }
                else if (item->key == node->key) // Item is the same as the node
                {
                    node->value = item->value;
                    free(item);
                    table->numberOfItemsInTable--; // Cancel out addition at end of function
                    done = 1;
                }
                node = node->next;
            }
        }

        // Update the number of items in the table and current load factor
        table->numberOfItemsInTable++;
        table->currentLoadFactor = _hashtable_get_load_factor(table);

        // Expand the table if needed
        if (table->currentLoadFactor - HASHTABLE_DEFAULT_MAX_POSITIVE_LOAD_FACTOR_VARIANCE > HASHTABLE_DEFAULT_LOAD_FACTOR)
            _hashtable_double_table(table);
    }
}


/**
 * Add an element to the hashtable
 * Assumes that you have already malloc()'d the value pointer
 * 
 * @param table The HashTable to be operated upon
 * @param key The key associated with the provided value
 * @param value The value to be associated with the key
 */
void hashtable_sput(hashtable_t *table, char *key, void *value)
{
    if (table != NULL && key != NULL)
    {
        unsigned long keyi = hashtable_hash_string(key);
        unsigned int hashValue = _hashtable_compute_index(table, keyi);

        hashtable_entry_t *item = malloc(sizeof(*item));

        item->next = NULL;
        item->value = value;
        item->key = keyi;

        // If this location in the table is empty, just add the node
        if (table->table[hashValue] == NULL)
        {
            table->table[hashValue] = item;
            table->numberOfSlotsUsed++;
        }
        else
        {
            hashtable_entry_t *node = table->table[hashValue];
            int done = 0;
            while (node != NULL && !done)
            {
                if ((item->key) > (node->key) && node->next == NULL)
                {
                    node->next = item;
                    done = 1;
                }
                else if (node->next != NULL && (item->key) < (node->next->key) && (item->key) > (node->key))
                {
                    item->next = node->next;
                    node->next = item;
                    done = 1;
                }
                else if (item->key < node->key)
                {
                    item->next = node;
                    table->table[hashValue] = item;
                    done = 1;
                }
                else if (item->key == node->key) // Item is the same as the node
                {
                    node->value = item->value;
                    free(item);
                    table->numberOfItemsInTable--; // Cancel out addition at end of function
                    done = 1;
                }
                node = node->next;
            }
        }

        // Update the number of items in the table and current load factor
        table->numberOfItemsInTable++;
        table->currentLoadFactor = _hashtable_get_load_factor(table);

        // Expand the table if needed
        if (table->currentLoadFactor - HASHTABLE_DEFAULT_MAX_POSITIVE_LOAD_FACTOR_VARIANCE > HASHTABLE_DEFAULT_LOAD_FACTOR)
            _hashtable_double_table(table);
    }
}


/**
 * Get an element from the hashtable based on the specified key
 * 
 * @param table The table in which to search for the key
 * @param key The key corresponsing to the value that will be returned
 * @return The value corresponding to the key specified 
 *         (NULL if table is NULL or it element does not exist)
 */
void *hashtable_get(hashtable_t *table, unsigned long key)
{
    if (table != NULL)
    {
        // Calculate the location in the table
        unsigned int hashValue = _hashtable_compute_index(table, key);
        hashtable_entry_t *node = table->table[hashValue];

        while (node != NULL)
        {
            if (node->key == key)
                return node->value;
            node = node->next;
        }
    }
    return NULL;
}


/**
 * Get an element from the hashtable based on the specified key
 * 
 * @param table The table in which to search for the key
 * @param key The key corresponsing to the value that will be returned
 * @return The value corresponding to the key specified 
 *         (NULL if table is NULL or it element does not exist)
 */
void *hashtable_sget(hashtable_t *table, char *key)
{
    if (table != NULL && key != NULL)
    {
        // Calculate the location in the table
        unsigned long keyi = hashtable_hash_string(key);
        unsigned int hashValue = _hashtable_compute_index(table, keyi);
        hashtable_entry_t *node = table->table[hashValue];

        while (node != NULL)
        {
            if (node->key == keyi)
                return node->value;
            node = node->next;
        }
    }
    return NULL;
}


/**
 * Remove an item from the table
 * 
 * @param table The table from which to remove an element
 * @param key The key for the value to be removed
 * @return The value associated with the key, NULL if no such element exists
 */
void *hashtable_remove(hashtable_t *table, unsigned long key)
{
    if (table != NULL)
    {
        // Calculate location in the table
        unsigned int hashValue = _hashtable_compute_index(table, key);
        hashtable_entry_t *node = table->table[hashValue];

        hashtable_entry_t *previousNode = NULL;

        while (node != NULL)
        {
            if (node->key == key)
            {
                if (previousNode == NULL)
                {
                    table->table[hashValue] = node->next;
                    if (node->next == NULL)
                        table->numberOfSlotsUsed--;
                }
                else
                {
                    previousNode->next = node->next;
                }

                // Update the number of items in the table and current load factor
                table->numberOfItemsInTable--;
                table->currentLoadFactor = ((float)table->numberOfSlotsUsed) / ((float)table->arraySize);
                
                // Shrink table if needed
                if (table->currentLoadFactor + HASHTABLE_DEFAULT_MAX_NGATIVE_LOAD_FACTOR_VARIANCE < HASHTABLE_DEFAULT_LOAD_FACTOR)
                    _hashtable_half_table(table);

                void *returnValue = node->value;
                /* free(node->value); */
                free(node);
                return returnValue; 
            }

            previousNode = node;
            node = node->next;
        }
    }
    return NULL; // Not Found
}


/**
 * Remove an item from the table
 * 
 * @param table The table from which to remove an element
 * @param key The key for the value to be removed
 * @return The value associated with the key, NULL if no such element exists
 */
void *hashtable_sremove(hashtable_t *table, char *key)
{
    if (table != NULL)
    {
        // Calculate location in the table
        unsigned long keyi = hashtable_hash_string(key);
        unsigned int hashValue = _hashtable_compute_index(table, keyi);
        hashtable_entry_t *node = table->table[hashValue];

        hashtable_entry_t *previousNode = NULL;

        while (node != NULL)
        {
            if (node->key == keyi)
            {
                if (previousNode == NULL)
                {
                    table->table[hashValue] = node->next;
                    if (node->next == NULL)
                        table->numberOfSlotsUsed--;
                }
                else
                {
                    previousNode->next = node->next;
                }

                // Update the number of items in the table and current load factor
                table->numberOfItemsInTable--;
                table->currentLoadFactor = ((float)table->numberOfSlotsUsed) / ((float)table->arraySize);

                // Shrink table if needed
                if (table->currentLoadFactor + HASHTABLE_DEFAULT_MAX_NGATIVE_LOAD_FACTOR_VARIANCE < HASHTABLE_DEFAULT_LOAD_FACTOR)
                    _hashtable_half_table(table);

                void *returnValue = node->value;
                /* free(node->value); */
                free(node);
                return returnValue;
            }

            previousNode = node;
            node = node->next;
        }
    }
    return NULL; // Not Found
}


/**
 * Search if a key exists
 * 
 * @param table The table in which to check for the key
 * @param key The key to search for
 * @return 1 if the key is found, 
 *         0 if not found or if table is NULL
 */
unsigned int hashtable_contains_key(hashtable_t *table, unsigned long key)
{
    if (table != NULL)
    {
        // Calculate location in the hashtable
        unsigned int hashValue = _hashtable_compute_index(table, key);
        hashtable_entry_t *node = table->table[hashValue];

        while (node != NULL)
        {
            if (node->key == key)
                return 1;
            node = node->next;
        }
    }
    return 0;
}


/**
 * Search if a key exists
 * 
 * @param table The table in which to check for the key
 * @param key The key to search for
 * @return 1 if the key is found, 
 *         0 if not found or if table is NULL
 */
unsigned int hashtable_contains_skey(hashtable_t *table, char *key)
{
    if (table != NULL)
    {
        // Calculate location in the hashtable
        unsigned long keyi = hashtable_hash_string(key);
        unsigned int hashValue = _hashtable_compute_index(table, keyi);
        hashtable_entry_t *node = table->table[hashValue];

        while (node != NULL)
        {
            if (node->key == keyi)
                return 1;
            node = node->next;
        }
    }
    return 0;
}


/**
 * Free a HashTable. 
 * Also free()s any values of any elements in the table
 * 
 * @param table The table to free
 */
void hashtable_destroy(hashtable_t **table)
{
    if (table != NULL && *table != NULL)
    {
        for (unsigned int i = 0; i < (*table)->arraySize; i++)
        {
            if ((*table)->table[i] != NULL)
            {
                free(((*table)->table[i])->value);
            }
            free((*table)->table[i]);
        }
        free((*table)->table);
        free(*table);
        *table = NULL;
    }
}


/**
 * Returns if the hashtable contains 0 elements
 *
 * @param table The table to check if empty
 * @return True (1) if there are 0 elements in the HashTable, 
 *         False (0) if not empty or if NULL table
 */
unsigned int hashtable_is_empty(hashtable_t *table) 
{
    if (table != NULL)
    {
        return (table->arraySize) == 0;
    }
    return 0;
}


/**
 * Returns the number of items in the hashtable
 * 
 * @param table The hashtable to retrieve the number of elements from
 * @return The number of elements in the table (0 if table is NULL)
 */
unsigned int hashtable_get_num_elements(hashtable_t *table)
{
    if (table != NULL)
    {
        return (table->numberOfItemsInTable);
    }
    return 0;
}


/**
 * Computes a hash value based off the input string
 * 
 * @param string The string to be hashed
 * @return The hashvalue of the string, 0 if string is NULL
 */
unsigned long hashtable_hash_string(const char *string)
{
    if (string != NULL)
    {
        // Algorithm based off:
        // http://www.cse.yorku.ca/~oz/hash.html
        // Apparently has "better distribution of the keys"
        int c;
        unsigned long hash = 0;
        while ((c = *string++))
        {
            hash += c + (hash << 6) + (hash << 16) - hash;
        }
        return hash;
    }
    return 0;
}


/**
 * Computes the pointer offset of a specified key into 
 * the hash table internal array
 * 
 * @param key The key to be "hashed"
 * @return The hash of the key 
 *         0 if the input table is NULL
 */
static unsigned int _hashtable_compute_index(hashtable_t *table, unsigned long key)
{
    if (table != NULL)
    {
        return key % (table->arraySize);
    }
    return 0;
}


// /**
//  * Get the average collision list length of the table
//  * 
//  * @param table The table to check collision list length average
//  * @return The average collision length of the collision lists in the table
//  *         -1 if the input table is NULL
//  */
// static float _hashtable_get_collision_average(hashtable_t *table)
// {
//     if (table != NULL)
//     {
//         return ((float)table->numberOfItemsInTable) / ((float)table->arraySize);
//     }
//     return -1;
// }


/**
 * Get the current table's load factor
 * 
 * @param table The table to check its load factor
 * @return The provided table's load factor
 *         -1 if the input table is NULL
 */
static float _hashtable_get_load_factor(hashtable_t *table)
{
    if (table != NULL)
    {
        return ((float)(table->numberOfItemsInTable)) / ((float)(table->arraySize));
    }
    return -1;
}


/**
 * Doubles the size of the array for the specified hashtable
 * 
 * @param table The table to be doubled in size
 */
static void _hashtable_double_table(hashtable_t *table)
{
    if (table != NULL)
    {
        // Keep a reference to the old table in the iterator
        hashtable_itr_t *itr = hashtable_create_iterator(table);
        table->arraySize = table->arraySize * 2;
        table->table = malloc(sizeof(hashtable_entry_t *) * table->arraySize);

        // Reset the values
        table->currentLoadFactor = 0;
        table->numberOfItemsInTable = 0;
        table->numberOfSlotsUsed = 0;

        for (unsigned int i = 0; i < table->arraySize; i++)
            table->table[i] = NULL;

        // Loop throught the original table and rehash them into the new table
        while (hashtable_iterator_has_next(itr))
        {
            hashtable_entry_t *node = hashtable_iterator_next(itr);
            hashtable_put(table, node->key, node->value);
        }
        hashtable_iterator_free(&itr);
    }
}


/**
 * Halve the size of the array for holding elements in the specified HashTable
 * 
 * @param table The table to be halved
 */
static void _hashtable_half_table(hashtable_t *table)
{
    if (table != NULL && (table->arraySize) >= (2 * HASHTABLE_INITIAL_SIZE))
    {
        // Keep a reference to the old table in the iterator
        hashtable_itr_t *itr = hashtable_create_iterator(table);

        table->arraySize = (table->arraySize) / 2;
        table->table = malloc(sizeof(hashtable_entry_t *) * table->arraySize);

        // Reset the values
        table->currentLoadFactor = 0;
        table->numberOfItemsInTable = 0;
        table->numberOfSlotsUsed = 0;

        for (unsigned int i = 0; i < table->arraySize; i++)
            table->table[i] = NULL;

        // Loop through all the values in the original table, rehashing them into the new one
        while (hashtable_iterator_has_next(itr))
        {
            hashtable_entry_t *node = hashtable_iterator_next(itr);
            hashtable_put(table, node->key, node->value);
        }
        hashtable_iterator_free(&itr);
    }
}


/** 
 * Return a new HashTableIterator
 * 
 * @param table The HashTable to create an Iterator from
 * @return A reference to the new HashTableIterator
 *         NULL if the input table is NULL
 */
hashtable_itr_t *hashtable_create_iterator(hashtable_t * table)
{
    if (table != NULL)
    {
        hashtable_itr_t *itr = (hashtable_itr_t *)malloc(sizeof(hashtable_itr_t));
        itr->currentNode = table->table[0];
        itr->currentTableIndex = 0;
        itr->foundElements = 0;
        itr->totalElements = table->numberOfItemsInTable;
        itr->tableSize = table->arraySize;
        itr->iteratorTable = table->table;
        // memcpy(itr->iteratorTable, table->table, sizeof(hashtable_entry_t) * table->arraySize);
        return itr;
    }
    return NULL;
}


/**
 * Check if there are any more remaining elements in the hashtable_itr_t
 * 
 * @param itr The iterator to use for checking
 * @return 1 if there are more elements,
 *         0 if there are no remaining elements (or input table is null)
 */
int hashtable_iterator_has_next(hashtable_itr_t * itr)
{
    if (itr != NULL)
    {
        return ((itr->foundElements) < (itr->totalElements)) && 
                ((itr->currentTableIndex) < (itr->tableSize) ||
                ((itr->currentNode) != NULL && (itr->currentNode)->next != NULL));
    }
    return 0;
}


/**
 * Return the next element in the hashtable
 * 
 * @param itr The iterator to pull the next element from
 * @return The next element as we iterate through the hash table
 *         NULL if there is no remaining elements
 */
hashtable_entry_t *hashtable_iterator_next(hashtable_itr_t * itr)
{
    if (itr != NULL)
    {
        if (hashtable_iterator_has_next(itr))
        {
            if (itr->currentNode != NULL)
            {
                hashtable_entry_t *returnNode = itr->currentNode;
                itr->currentNode = itr->currentNode->next;
                ++itr->foundElements;
                return returnNode;
            }
            else
            {
                itr->currentNode = itr->iteratorTable[++(itr->currentTableIndex)];
                return hashtable_iterator_next(itr);
            }
        }
        return NULL;
    }
    return NULL;
}


/**
 * Free a hashtable_itr_t
 * 
 * @param itr The iterator to free
 */
void hashtable_iterator_free(hashtable_itr_t **itr)
{
    if (itr != NULL && *itr != NULL)
    {
        free(*itr);
        (*itr) = NULL;
    }
}

