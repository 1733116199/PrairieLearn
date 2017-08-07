
CREATE OR REPLACE FUNCTION
    variants_insert(
        IN variant_seed text,
        IN params jsonb,
        IN true_answer jsonb,
        IN options jsonb,
        IN valid boolean,
        IN instance_question_id bigint, -- can be NULL
        IN question_id bigint,          -- can be NULL, but needed if instance_question_id is NULL
        IN user_id bigint,              -- can be NULL, but needed if instance_question_id is NULL
        IN authn_user_id bigint,
        OUT variant variants
    )
AS $$
DECLARE
    real_question_id bigint;
    real_user_id bigint;
    new_number integer;
BEGIN
    -- The caller must have provided either instance_question_id or
    -- the (question_id, user_id). If instance_question_id is not
    -- NULL, then we use it to look up the other two. Otherwise we
    -- just use them.

    IF instance_question_id IS NOT NULL THEN
        SELECT           q.id,    u.user_id
        INTO real_question_id, real_user_id
        FROM
            instances_questions AS iq
            JOIN assessment_questions AS aq ON (aq.id = iq.assessment_question_id)
            JOIN questions AS q ON (q.id = aq.question_id)
            JOIN assessment_instances AS ai ON (ai.id = iq.assessment_instance_id)
            JOIN users AS u ON (u.user_id = ai.user_id)
        WHERE
            iq.id = instance_question_id;

        IF NOT FOUND THEN RAISE EXCEPTION 'instance_question not found'; END IF;

        SELECT max(v.number)
        INTO new_number
        FROM variants AS v
        WHERE v.instance_question_id = instance_question_id;

        new_number := coalesce(new_number + 1, 1);
    ELSE
        -- we weren't given an instance_question_id, so we must have
        -- question_id and user_id
        IF question_id IS NULL THEN RAISE EXCEPTION 'no instance_question_id and no question_id'; END IF;
        IF user_id IS NULL THEN RAISE EXCEPTION 'no instance_question_id and no user_id'; END IF;

        real_question_id := question_id;
        real_user_id := user_id;
    END IF;

    INSERT INTO variants
        (instance_question_id,      question_id,      user_id,
        number,     variant_seed, params, true_answer, options, valid, authn_user_id)
    VALUES
        (instance_question_id, real_question_id, real_user_id,
        new_number, variant_seed, params, true_answer, options, valid, authn_user_id)
    RETURNING *
    INTO variant;
END;
$$ LANGUAGE plpgsql VOLATILE;
