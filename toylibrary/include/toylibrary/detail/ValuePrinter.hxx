
#include "ers/ers.h"

namespace dunedaq::toylibrary {
  
  template <typename T>
  void ValuePrinter<T>::ShowValue() const {
    ERS_INFO("The value is " << obtained_value_);
  }

} // namespace dunedaq::toylibrary
