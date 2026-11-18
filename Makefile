# Smart File Explorer: build, GoogleTest, gcov and Cppcheck
SHELL := /bin/bash

CXX := g++
TARGET := explorer
BUILD_DIR := build

CXXFLAGS := -std=c++17 -Wall -Wextra -Wpedantic -O2 -g
CPPFLAGS := -I.

APP_SOURCES := main.cpp \
               FileExplorer.cpp \
               DirectoryManager.cpp \
               FileSystemItem.cpp \
               FileItem.cpp \
               FolderItem.cpp \
               ContextMenu.cpp \
               FileManager.cpp \
               ClipboardManager.cpp \
               SearchEngine.cpp \
               FileViewer.cpp \
               StorageAnalyzer.cpp

TEST_SOURCES := $(wildcard test*.cpp)

APP_OBJECTS := $(patsubst %.cpp,$(BUILD_DIR)/app/%.o,$(APP_SOURCES))
TEST_APP_SOURCES := $(filter-out main.cpp,$(APP_SOURCES))
TEST_APP_OBJECTS := $(patsubst %.cpp,$(BUILD_DIR)/test-app/%.o,$(TEST_APP_SOURCES))

TEST_OBJECTS := $(patsubst %.cpp,$(BUILD_DIR)/tests/%.o,$(TEST_SOURCES))
TEST_BIN := $(BUILD_DIR)/explorer_tests

COV_DIR := $(BUILD_DIR)/coverage
COV_APP_OBJECTS := $(patsubst %.cpp,$(COV_DIR)/app/%.o,$(TEST_APP_SOURCES))
COV_TEST_OBJECTS := $(patsubst %.cpp,$(COV_DIR)/tests/%.o,$(TEST_SOURCES))
COV_TEST_BIN := $(COV_DIR)/explorer_tests

AUDIT_LOG := audit_report.log

.PHONY: all run test coverage cppcheck valgrind quality clean audit help check-tests

all: $(TARGET)

$(TARGET): $(APP_OBJECTS)
	$(CXX) $(CXXFLAGS) $^ -o $@
	@echo "Build successful: $@"

$(BUILD_DIR)/app/%.o: %.cpp
	@mkdir -p $(dir $@)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -MMD -MP -c $< -o $@

$(BUILD_DIR)/test-app/%.o: %.cpp
	@mkdir -p $(dir $@)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -MMD -MP -c $< -o $@

$(BUILD_DIR)/tests/%.o: %.cpp
	@mkdir -p $(dir $@)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -MMD -MP -c $< -o $@

run: $(TARGET)
	./$(TARGET)

check-tests:
	@if [ -z "$(TEST_SOURCES)" ]; then \
		echo "No tests found. Add GoogleTest .cpp files to the project root."; \
		exit 1; \
	fi

test: check-tests $(TEST_BIN)
	./$(TEST_BIN)

$(TEST_BIN): $(TEST_APP_OBJECTS) $(TEST_OBJECTS)
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) $^ -o $@ -lgtest_main -lgtest -pthread

$(COV_DIR)/app/%.o: %.cpp
	@mkdir -p $(dir $@)
	$(CXX) $(CPPFLAGS) -std=c++17 -Wall -Wextra -Wpedantic -O0 -g --coverage -MMD -MP -c $< -o $@

$(COV_DIR)/tests/%.o: %.cpp
	@mkdir -p $(dir $@)
	$(CXX) $(CPPFLAGS) -std=c++17 -Wall -Wextra -Wpedantic -O0 -g --coverage -MMD -MP -c $< -o $@

$(COV_TEST_BIN): $(COV_APP_OBJECTS) $(COV_TEST_OBJECTS)
	@mkdir -p $(dir $@)
	$(CXX) --coverage $^ -o $@ -lgtest_main -lgtest -pthread

coverage: check-tests $(COV_TEST_BIN)
	@echo "Running tests..."
	@./$(COV_TEST_BIN) > /dev/null
	@echo "Generating gcov reports..."
	@mkdir -p $(COV_DIR)/gcov
	@# Run gcov from the root directory. Redirect stdout summary to a text file.
	@gcov -b -c -o $(COV_DIR)/app $(TEST_APP_SOURCES) > $(COV_DIR)/summary.txt 2>&1 || true
	@mv *.gcov $(COV_DIR)/gcov/ 2>/dev/null || true
	@echo "Coverage reports generated in $(COV_DIR)/gcov/"
	@echo "--------------------------------------------------"
	@echo "                 COVERAGE SUMMARY                 "
	@echo "--------------------------------------------------"
	@grep -E "File '|Lines executed" $(COV_DIR)/summary.txt || echo "No coverage data found."

cppcheck:
	cppcheck --enable=warning,style,performance,portability \
	         --inline-suppr --std=c++17 --language=c++ \
	         --suppress=missingIncludeSystem \
	         $(APP_SOURCES) $(wildcard *.h) $(TEST_SOURCES)

valgrind: test
	@echo "Running Valgrind Memory Analysis on Tests..."
	valgrind --leak-check=full --show-leak-kinds=all ./$(TEST_BIN)

quality: test coverage cppcheck

clean:
	rm -rf $(BUILD_DIR) $(TARGET) *.gcda *.gcno *.gcov $(AUDIT_LOG)

audit:
	@rm -f $(AUDIT_LOG)
	@echo "==================================================" >> $(AUDIT_LOG)
	@echo "TIMESTAMP: $$(date)" >> $(AUDIT_LOG)
	@echo "ACTION: Compilation and GTest Execution" >> $(AUDIT_LOG)
	@echo "==================================================" >> $(AUDIT_LOG)
	@$(MAKE) clean >> $(AUDIT_LOG) 2>&1
	@$(MAKE) test >> $(AUDIT_LOG) 2>&1
	
	@echo -e "\n==================================================" >> $(AUDIT_LOG)
	@echo "TIMESTAMP: $$(date)" >> $(AUDIT_LOG)
	@echo "ACTION: GCOV Coverage Analysis" >> $(AUDIT_LOG)
	@echo "==================================================" >> $(AUDIT_LOG)
	@$(MAKE) coverage >> $(AUDIT_LOG) 2>&1

	@echo -e "\n==================================================" >> $(AUDIT_LOG)
	@echo "TIMESTAMP: $$(date)" >> $(AUDIT_LOG)
	@echo "ACTION: Valgrind Memory Analysis (Tests)" >> $(AUDIT_LOG)
	@echo "==================================================" >> $(AUDIT_LOG)
	@valgrind --leak-check=full ./$(TEST_BIN) >> $(AUDIT_LOG) 2>&1
	
	@echo -e "\n==================================================" >> $(AUDIT_LOG)
	@echo "TIMESTAMP: $$(date)" >> $(AUDIT_LOG)
	@echo "ACTION: Cppcheck Static Analysis" >> $(AUDIT_LOG)
	@echo "==================================================" >> $(AUDIT_LOG)
	@cppcheck --enable=warning,performance,portability --std=c++17 -I. --suppress=missingIncludeSystem $(APP_SOURCES) $(TEST_SOURCES) >> $(AUDIT_LOG) 2>&1
	
	@echo "✅ Audit complete! Check '$(AUDIT_LOG)' for the timestamped report."

-include $(APP_OBJECTS:.o=.d)
-include $(TEST_APP_OBJECTS:.o=.d)
-include $(TEST_OBJECTS:.o=.d)
-include $(COV_APP_OBJECTS:.o=.d)
-include $(COV_TEST_OBJECTS:.o=.d)

help:
	@echo "make          Build application"
	@echo "make run      Build and run application"
	@echo "make test     Build and run GoogleTest tests"
	@echo "make coverage Run tests with gcov instrumentation"
	@echo "make cppcheck Run Cppcheck static analysis"
	@echo "make valgrind Run Valgrind memory analysis on tests"
	@echo "make quality  Run tests, coverage and Cppcheck"
	@echo "make audit    Run full audit (clean, test, coverage, valgrind, cppcheck) into log"
	@echo "make clean    Remove generated files"
