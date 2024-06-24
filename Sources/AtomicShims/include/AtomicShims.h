#include <stdatomic.h>

typedef struct AtomicInt
{
    atomic_intptr_t value;
} AtomicInt;

intptr_t exchange(AtomicInt *atomic_value, intptr_t value);

void store(AtomicInt *atomic_value, intptr_t value);

intptr_t load(AtomicInt *atomic_value);
