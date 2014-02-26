TeamCity-extensions
===================

How to wrap TeamCity NUnit Runner with powershell?

Here is the example.

You may try Platform\build\TestProduct\Impl\InTest\RunTests.ps1

- locally and nunit-console will be used
- at TeamCity and TeamCity runner will be used

When your build scripts are relativelly complicated, than the ability to run the whole thing locally became very desirable.

You may use Powershell Jobs to run tests in parallel by assembly. (not currently included feature)