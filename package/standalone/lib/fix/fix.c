#include "ctype.h"
#include "setlocale.h"

const char *
__locale_ctype_ptr (void)
{
  return __get_current_locale ()->ctype_ptr;
}
