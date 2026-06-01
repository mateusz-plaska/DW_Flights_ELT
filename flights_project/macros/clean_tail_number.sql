{% macro clean_tail_number(column_name) %}
    CASE
        WHEN UPPER(LTRIM(RTRIM(CAST({{ column_name }} AS VARCHAR)))) NOT LIKE 'N%'
            THEN 'N' + UPPER(LTRIM(RTRIM(CAST({{ column_name }} AS VARCHAR))))
        ELSE UPPER(LTRIM(RTRIM(CAST({{ column_name }} AS VARCHAR))))
    END
{% endmacro %}