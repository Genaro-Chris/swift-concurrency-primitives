#include "AtomicShims.h"

void store(AtomicInt *atomic_value, intptr_t value)
{
    atomic_store_explicit(&atomic_value->value, value, __ATOMIC_RELAXED);
}

intptr_t load(AtomicInt *atomic_value)
{
    return atomic_load_explicit(&atomic_value->value, __ATOMIC_ACQUIRE);
}

intptr_t exchange(AtomicInt *atomic_value, intptr_t value)
{
    return atomic_exchange_explicit(&atomic_value->value, value, __ATOMIC_RELEASE);
}
