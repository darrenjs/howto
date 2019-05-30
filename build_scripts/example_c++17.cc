/* C++17 example */

#include <any>
#include <iostream>
#include <map>
#include <variant>



int main(int /* argc */, const char** /* argc */)
{

  /* example of std::any */

  std::any a(12);
  a = std::string("Hello!");
  a = 16;
  std::cout << std::any_cast<int>(a) << '\n'; // print as int

  /* example of std::variant */

  std::variant<int, float, std::string> intFloatString;
  static_assert(std::variant_size_v<decltype(intFloatString)> == 3);

  /* === Example from C++17 In Detail -- Bartłomiej Filipek" === */

  std::map<std::string, int> mapUsersAge { { "C++", 11} };

  // type deduced
  std::map mapCopy{std::begin(mapUsersAge), std::end(mapUsersAge)};

  // new map insertor, structured bindings, init-if
  if (auto [iter, wasAdded] = mapCopy.insert_or_assign("C++", 17); !wasAdded)
    std::cout << iter->first << " reassigned..." << std::endl;

  for (const auto& [key, value] : mapCopy)
    std::cout << key << ", " << value << std::endl;

  // constexpr lambda expressions -- following doesn't compile in C++11/14
  auto SimpleLambda = [] (int n) { return n; };
  static_assert(SimpleLambda(3) == 3, "");

  return 0;
}
